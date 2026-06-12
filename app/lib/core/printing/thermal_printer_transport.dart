import 'dart:io';

import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_basic/flutter_bluetooth_basic.dart';
import 'thermal_printer_settings.dart';

bool get thermalBluetoothSupported {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

class ThermalPrinterTransport {
  ThermalPrinterTransport(this._bluetoothManager);

  final PrinterBluetoothManager _bluetoothManager;

  Future<void> send(
    ThermalPrinterSettings settings,
    List<int> bytes,
  ) async {
    if (kIsWeb) {
      throw Exception('Cetak thermal tidak tersedia di web');
    }
    if (!settings.isConfigured) {
      throw Exception('Printer belum dikonfigurasi di Pengaturan Printer');
    }

    if (settings.isWifi) {
      await _sendWifi(settings.host, settings.port, bytes);
      return;
    }

    if (!thermalBluetoothSupported) {
      throw Exception('Bluetooth hanya tersedia di Android/iOS');
    }

    await _sendBluetooth(settings, bytes);
  }

  Future<void> _sendWifi(String host, int port, List<int> bytes) async {
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 5),
    );
    try {
      socket.add(bytes);
      await socket.flush();
    } finally {
      await socket.close();
    }
  }

  Future<void> _sendBluetooth(
    ThermalPrinterSettings settings,
    List<int> bytes,
  ) async {
    final address = settings.bluetoothAddress!.trim();
    final device = BluetoothDevice()
      ..name = settings.bluetoothName ?? address
      ..address = address;

    _bluetoothManager.selectPrinter(PrinterBluetooth(device));
    final result = await _bluetoothManager.printTicket(bytes);
    if (result != PosPrintResult.success) {
      throw Exception('Bluetooth print failed: ${result.msg}');
    }
  }
}
