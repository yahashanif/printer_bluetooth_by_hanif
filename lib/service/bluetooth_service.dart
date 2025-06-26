import 'dart:async';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class BluetoothService {
  static List<BluetoothInfo> devices = [];
  static Timer? _timer;

  static void startConnectionMonitor(Function(bool) onStatusChanged) {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 3), (_) async {
      final status = await PrintBluetoothThermal.connectionStatus;
      onStatusChanged(status);
    });
  }

  static void stopConnectionMonitor() {
    _timer?.cancel();
  }

  static Future<void> getBluetooth() async {
    devices = await PrintBluetoothThermal.pairedBluetooths;
  }

  static Future<void> connect(String mac) async {
    await PrintBluetoothThermal.connect(macPrinterAddress: mac);
  }

  static Future<bool> write(List<int> bytes) async {
    return await PrintBluetoothThermal.writeBytes(bytes);
  }
}
