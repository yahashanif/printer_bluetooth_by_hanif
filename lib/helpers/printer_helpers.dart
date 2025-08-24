import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<List<int>> buildReceiptFromJsonTemplate(
  Map<String, dynamic> template,
  Map<String, dynamic> payload,
) async {
  final profile = await CapabilityProfile.load();
  final paperSize =
      template["paperSize"] == "mm80" ? PaperSize.mm80 : PaperSize.mm58;
  final gen = Generator(paperSize, profile);
  List<int> bytes = [];

  for (var element in template["elements"]) {
    final type = element["type"];
    final style = parseStyle(element["style"]);
    final align = style.align;

    if (type == "image") {
      final key = element["key"];
      final url = payload[key];
      if (url == null) continue;

      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final imageBytes = response.bodyBytes;
          final image = decodeImage(Uint8List.fromList(imageBytes));
          if (image != null) {
            bytes += gen.image(
              image,
              align: align,
            );
          } else {
            print("❌ Gagal decode image dari response");
          }
        } else {
          print("❌ Error HTTP: ${response.statusCode}");
        }
      } catch (e) {
        print("❌ Error ambil image dari URL: $e");
      }
    } else if (type == "text") {
      final key = element["key"];
      final templateText = element["template"];
      String text = key != null ? (payload[key] ?? "").toString() : "";
      if (templateText != null) {
        text = templateText.replaceAllMapped(RegExp(r"\{(.*?)\}"), (match) {
          final key = match.group(1)!;
          return payload[key]?.toString() ?? "";
        });
      }
      bytes += gen.text(text, styles: style);
    } else if (type == "divider") {
      final line = '-' * (paperSize == PaperSize.mm80 ? 48 : 32);
      bytes += gen.text(line);
    } else if (type == "row") {
      final columns = element["columns"] as List;
      bytes += gen.row(columns.map((col) {
        final template = col["template"] ?? "";
        final text = template.toString().replaceAllMapped(
              RegExp(r"\{(.*?)\}"),
              (match) => payload[match.group(1)!]?.toString() ?? "",
            );
        return PosColumn(
          text: text,
          width: col["width"] ?? 6,
          styles: PosStyles(
            align: parseAlign(col["align"]),
            bold: col["bold"] == true,
          ),
        );
      }).toList());
      bytes += gen.feed(1);
    } else if (type == "table") {
      final columns = element["columns"] as List;
      final key = element["key"] ?? "items";
      final items = payload[key] as List;
      for (var item in items) {
        bytes += gen.row(columns.map((col) {
          final key = col["key"];
          final width = col["width"] ?? 1;
          final align = parseAlign(col["align"]);
          return PosColumn(
            text: item[key].toString(),
            width: width,
            styles: PosStyles(align: align),
          );
        }).toList());
      }
    } else if (type == "custom_items") {
      final items = payload["items"] as List;
      for (var i = 0; i < items.length; i++) {
        final item = items[i];

        // Baris pertama: no. + nama
        bytes += gen.text("${item["name"]}", styles: PosStyles(bold: true));

        // Baris kedua: qty kiri, total kanan
        bytes += gen.row([
          PosColumn(
            text: item["qty"].toString(),
            width: 9,
            styles: PosStyles(align: PosAlign.left),
          ),
          PosColumn(
            text: item["total"].toString(),
            width: 3,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
      }
      bytes += gen.feed(1);
    } else if (type == "barcode") {
      final key = element["key"];
      final format =
          (element["format"] ?? "barcode").toLowerCase(); // default barcode
      final data = payload[key];

      if (data == null) {
        print("⚠️ Data for barcode key '$key' is null, skipping.");
        continue;
      }

      print("Format: $format | Data: $data");

      if (format == "qrcode") {
        // QR Code handling
        String qrData = data.toString();
        const double qrSize = 200;

        try {
          final uiImg = await QrPainter(
            data: qrData,
            version: QrVersions.auto,
            gapless: false,
          ).toImageData(qrSize);

          final dir = await getTemporaryDirectory();
          final pathName = '${dir.path}/qr_tmp.png';
          final qrFile = File(pathName);
          final imgFile =
              await qrFile.writeAsBytes(uiImg!.buffer.asUint8List());
          final img = decodeImage(imgFile.readAsBytesSync());

          if (img != null) {
            bytes += gen.image(img, align: PosAlign.center);
          } else {
            print("❌ Failed to decode image for QR code");
          }
        } catch (e) {
          print("❌ QR code generation error: $e");
        }
      } else if (format == "barcode") {
        // Barcode handling

        try {
          data is List<int>
              ? data // If data is already a list of integers
              : (data is String
                  ? data.codeUnits // Convert string to code units
                  : <int>[]); // Default to empty list if not convertible
          final List<int> barData = data is List<int>
              ? data
              : (data is String ? data.codeUnits : <int>[]);
          if (barData.isEmpty) {
            print("⚠️ No valid data for barcode, skipping.");
            continue;
          }
          // Ensure barData is a valid UPC-A code (12 digits)
          if (barData.length != 12) {
            print(
                "⚠️ UPC-A barcode requires exactly 12 digits, got ${barData.length}");
            continue;
          }
          bytes += gen.barcode(Barcode.upcA(barData));
        } catch (e) {
          print("❌ Barcode generation error: $e");
        }
      } else {
        print("⚠️ Unknown barcode format '$format'");
      }

      bytes += gen.feed(0);
    } else if (type == "custom_payments" || type == "payments") {
      final payments = payload["payments"] as List?;
      if (payments != null && payments.isNotEmpty) {
        bytes += gen.text("Payment:", styles: PosStyles(bold: true));
        for (var pay in payments) {
          final name = pay["name"] ?? "";
          final total = pay["total"] ?? "";
          // Format: - Cash         Rp 50.000 (rata kiri-kanan)
          bytes += gen.row([
            PosColumn(
              text: "- $name",
              width: 6,
              styles: PosStyles(
                align: PosAlign.left,
                bold: true,
              ),
            ),
            PosColumn(
              text: total,
              width: 6,
              styles: PosStyles(
                align: PosAlign.right,
                bold: true,
              ),
            ),
          ]);
        }
        bytes += gen.feed(1);
      }
    }

    bytes += gen.feed(0); // feed after each element
  }

  bytes += gen.cut();
  return bytes;
}

PosStyles parseStyle(Map? styleJson) {
  if (styleJson == null) return PosStyles();
  return PosStyles(
    align: parseAlign(styleJson["align"]),
    bold: styleJson["bold"] == true,
  );
}

PosAlign parseAlign(String? align) {
  switch (align) {
    case "right":
      return PosAlign.right;
    case "center":
      return PosAlign.center;
    default:
      return PosAlign.left;
  }
}
