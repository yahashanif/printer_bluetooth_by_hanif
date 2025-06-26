import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../service/bluetooth_service.dart';

class BluetoothDropdown extends StatefulWidget {
  final Function(String) onSelectDevice;

  const BluetoothDropdown({required this.onSelectDevice, super.key});

  @override
  State<BluetoothDropdown> createState() => _BluetoothDropdownState();
}

class _BluetoothDropdownState extends State<BluetoothDropdown> {
  String? selectedMac;

  @override
  Widget build(BuildContext context) {
    final devices = BluetoothService.devices;

    return DropdownButton<String>(
      isExpanded: true,
      hint: const Text('Pilih perangkat Bluetooth'),
      value: selectedMac,
      items: devices.map((device) {
        return DropdownMenuItem<String>(
          value: device.macAdress,
          child: Text('${device.name} (${device.macAdress})'),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            selectedMac = value;
          });
          widget.onSelectDevice(value);
        }
      },
    );
  }
}
