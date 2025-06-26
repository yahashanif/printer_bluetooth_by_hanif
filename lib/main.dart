import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'helpers/printer_helpers.dart';
import 'service/bluetooth_service.dart';
import 'template/printer_templates.dart';
import 'widgets/bluetooth_list.dart'; // pastikan BluetoothDropdown sudah jadi

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool connected = false;
  bool isPrinting = false;
  bool isWebSocketConnected = false;

  WebSocketChannel? channel;
  final TextEditingController urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    BluetoothService.startConnectionMonitor((status) {
      setState(() => connected = status);
    });
  }

  @override
  void dispose() {
    BluetoothService.stopConnectionMonitor();
    BluetoothService.getBluetooth(); // clear devices list
    channel?.sink.close();
    urlController.dispose();
    super.dispose();
  }

  void connectWebSocket(String url) {
    try {
      channel?.sink.close(); // tutup koneksi lama jika ada

      final newChannel = WebSocketChannel.connect(Uri.parse(url));
      setState(() {
        channel = newChannel;
        isWebSocketConnected = true;
      });

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
    final url = urlController.text.trim();
    if (url.isNotEmpty) {
      Future.delayed(const Duration(seconds: 5), () {
        if (!isWebSocketConnected) {
          print("🔄 Attempting to reconnect WebSocket...");
          connectWebSocket(url);
        }
      });
    }
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
                  labelText: 'WebSocket URL',
                  hintText: 'ws://yourserver.com/ws',
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  final url = urlController.text.trim();
                  if (url.isNotEmpty) {
                    connectWebSocket(url);
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
