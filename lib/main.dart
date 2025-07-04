import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'helpers/printer_helpers.dart';
import 'service/bluetooth_service.dart';
import 'template/printer_templates.dart';
import 'widgets/bluetooth_list.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool connected = false;
  bool isPrinting = false;
  bool isCheckKeyWebsocket = false;
  bool isWebSocketConnected = false;
  String codePrint = '';
  bool isEditCode = true;

  WebSocketChannel? channel;
  final TextEditingController codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getCodePrint().then((_) {
      codeController.text = codePrint;
      if (codePrint.isNotEmpty) isEditCode = false;
      setState(() {});
    });

    BluetoothService.startConnectionMonitor((status) {
      setState(() => connected = status);
    });

    connectWebSocket();
  }

  Future<void> getCodePrint() async {
    final prefs = await SharedPreferences.getInstance();
    codePrint = prefs.getString('codePrint') ?? '';
  }

  Future<void> setCodePrint(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('codePrint', code);
  }

  @override
  void dispose() {
    BluetoothService.stopConnectionMonitor();
    BluetoothService.getBluetooth();
    channel?.sink.close();
    codeController.dispose();
    super.dispose();
  }

  Future<void> connectWebSocket() async {
    try {
      channel?.sink.close();
      final url = dotenv.get('WEBSOCKET_URL', fallback: 'WS');
      final newChannel = WebSocketChannel.connect(Uri.parse(url));
      await newChannel.ready;

      setState(() {
        channel = newChannel;
        isWebSocketConnected = true;
      });

      newChannel.sink.add(jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'channel': 'order-print-mobile'},
      }));

      newChannel.stream.listen(
        (data) {
          final decoded = json.decode(data);
          final event = decoded['event'];
          final eventData = decoded['data'];
          final decodeSecond = json.decode(eventData);
          if (codeController.text == decodeSecond['key']) {
            _handleWebSocketMessage(decodeSecond);
          }
        },
        onError: (error) {
          print("⚠️ WebSocket error: $error");
          setState(() => isWebSocketConnected = false);
          _autoReconnectWebSocket();
        },
        onDone: () {
          print("❌ WebSocket connection closed");
          setState(() => isWebSocketConnected = false);
          _autoReconnectWebSocket();
        },
      );

      print("✅ Connected to WebSocket at $url");
    } catch (e) {
      print("❌ Gagal connect WebSocket: $e");
      setState(() => isWebSocketConnected = false);
      _autoReconnectWebSocket();
    }
  }

  void _autoReconnectWebSocket() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!isWebSocketConnected) {
        connectWebSocket();
      }
    });
  }

  Future<void> _handleWebSocketMessage(dynamic jsonString) async {
    setState(() => isPrinting = true);

    if (!connected) {
      print("⚠️ Printer not connected");
      setState(() => isPrinting = false);
      return;
    }

    try {
      final payload = jsonString['payload'];
      final templateWeb = jsonString['template'];
      final bytes = await buildReceiptFromJsonTemplate(templateWeb, payload);
      final result = await BluetoothService.write(bytes);
      print(result ? "✅ Receipt sent to printer" : "❌ Failed to send receipt");
    } catch (e) {
      print("⚠️ Error processing WebSocket data: $e");
    }

    setState(() => isPrinting = false);
  }

  Future<void> printReceipt() async {
    setState(() => isPrinting = true);

    if (!connected) {
      print("⚠️ Printer not connected");
      setState(() => isPrinting = false);
      return;
    }

    final bytes = await buildReceiptFromJsonTemplate(template, payload);
    final result = await BluetoothService.write(bytes);

    print(result ? "✅ Receipt sent to printer" : "❌ Failed to send receipt");

    setState(() => isPrinting = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Printer App',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Bluetooth Thermal Printer'),
          actions: [
            Icon(
              isWebSocketConnected ? Icons.cloud_done : Icons.cloud_off,
              color: isWebSocketConnected ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🔌 PRINTER STATUS
              Row(
                children: [
                  Icon(
                    connected ? Icons.print : Icons.print_disabled,
                    color: connected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    connected ? "Printer Connected" : "Printer Not Connected",
                    style: TextStyle(
                      color: connected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const Divider(height: 30),

              /// 🔍 BLUETOOTH SECTION
              const Text("Bluetooth Devices",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: BluetoothService.getBluetooth,
                icon: const Icon(Icons.search),
                label: const Text("Search Paired Devices"),
              ),
              BluetoothDropdown(
                onSelectDevice: (mac) {
                  BluetoothService.connect(mac);
                },
              ),

              const Divider(height: 30),

              /// 🧾 CODE SETTING
              const Text("Connection Key",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                codePrint.isEmpty ? "No code available" : "Code: $codePrint",
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 5),
              if (!isEditCode)
                InkWell(
                  onTap: () {
                    setState(() => isEditCode = true);
                  },
                  child: const Text("Edit Code",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontStyle: FontStyle.italic)),
                ),
              if (isEditCode)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    TextField(
                      controller: codeController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Connection Key',
                      ),
                      maxLength: 6,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final code = codeController.text.trim();
                        if (code.isNotEmpty) {
                          await setCodePrint(code);
                          await getCodePrint();
                          setState(() => isEditCode = false);
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: const Text("Save Code"),
                    ),
                  ],
                ),

              const Divider(height: 30),

              /// 🖨 MANUAL PRINT
              isPrinting
                  ? const Center(child: CircularProgressIndicator())
                  : TextButton.icon(
                      onPressed: connected ? printReceipt : null,
                      icon: const Icon(Icons.print),
                      label: const Text("Print Receipt"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
