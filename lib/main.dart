import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'helpers/printer_helpers.dart';
import 'service/bluetooth_service.dart';
import 'template/printer_templates.dart';
import 'widgets/bluetooth_list.dart'; // pastikan BluetoothDropdown sudah jadi

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool connected = false;
  bool isPrinting = false;
  bool isCheckKeyWebsocket = false;
  bool isWebSocketConnected = false;

  WebSocketChannel? channel;
  final TextEditingController urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    BluetoothService.startConnectionMonitor((status) {
      setState(() => connected = status);
    });

    connectWebSocket();
  }

  @override
  void dispose() {
    BluetoothService.stopConnectionMonitor();
    BluetoothService.getBluetooth(); // clear devices list
    channel?.sink.close();
    urlController.dispose();
    super.dispose();
  }

  Future<void> connectWebSocket() async {
    try {
      channel?.sink.close(); // tutup koneksi lama jika ada

      final url = dotenv.get('WEBSOCKET_URL', fallback: 'WS');
      final newChannel = WebSocketChannel.connect(Uri.parse(url));

      await newChannel.ready;

      setState(() {
        channel = newChannel;
        isWebSocketConnected = true;
      });

      newChannel.sink.add(
        jsonEncode({
          'event': 'pusher:subscribe',
          'data': {'channel': 'order-print-mobile'},
        }),
      );

      newChannel.stream.listen(
        (data) {
          print("📥 Data dari WebSocket: $data");
          _handleWebSocketMessage(data);
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
        print("🔄 Attempting to reconnect WebSocket...");
        connectWebSocket();
      }
    });
  }

  Future<void> _handleWebSocketMessage(String jsonString) async {
    setState(() => isPrinting = true);

    if (!connected) {
      print("⚠️ Printer not connected");
      setState(() => isPrinting = false);
      return;
    }

    try {
      final payload = json.decode(jsonString);
      final bytes = await buildReceiptFromJsonTemplate(template, payload);
      final result = await BluetoothService.write(bytes);

      if (result) {
        print("✅ Receipt sent to printer");
      } else {
        print("❌ Failed to send receipt");
      }
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

    if (result) {
      print("✅ Receipt sent to printer");
    } else {
      print("❌ Failed to send receipt");
    }

    setState(() => isPrinting = false);
  }

  Future<void> validateWebsocketKey(String key) async {
    setState(() => isCheckKeyWebsocket = true);

    if (!connected) {
      print("⚠️ Printer not connected");
      setState(() => isPrinting = false);
      return;
    }

    final bytes = await buildReceiptFromJsonTemplate(template, payload);
    final result = await BluetoothService.write(bytes);

    if (result) {
      print("✅ Receipt sent to printer");
    } else {
      print("❌ Failed to send receipt");
    }

    setState(() => isPrinting = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bluetooth Thermal Printer'),
              Text(
                isWebSocketConnected
                    ? "🟢 WebSocket Connected"
                    : "🔴 WebSocket Disconnected",
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                connected ? "✅ Printer Connected" : "❌ Printer Not Connected",
                style: TextStyle(
                  color: connected ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: BluetoothService.getBluetooth,
                child: const Text("Search Paired Bluetooth"),
              ),
              BluetoothDropdown(
                onSelectDevice: (mac) {
                  BluetoothService.connect(mac);
                },
              ),
              const SizedBox(height: 20),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Connection Key',
                  hintText: 'e.g. abc123',
                ),
                maxLength: 6,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  final url = urlController.text.trim();
                  if (url.isNotEmpty) {
                    validateWebsocketKey(url);
                  }
                },
                child: Text(isWebSocketConnected
                    ? "🔌 WebSocket Connected"
                    : "Connect WebSocket"),
              ),
              const SizedBox(height: 20),
              isPrinting
                  ? const Center(child: CircularProgressIndicator())
                  : TextButton(
                      onPressed: connected ? printReceipt : null,
                      child: const Text("Print Receipt"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
