import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'thermal_printer_service.dart';
import 'thermal_printer_settings.dart';
import 'thermal_printer_transport.dart';

final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefsProvider must be overridden');
});

final printerBluetoothManagerProvider = Provider<PrinterBluetoothManager>((ref) {
  final manager = PrinterBluetoothManager();
  ref.onDispose(manager.stopScan);
  return manager;
});

final thermalPrinterTransportProvider = Provider<ThermalPrinterTransport>((ref) {
  return ThermalPrinterTransport(ref.watch(printerBluetoothManagerProvider));
});

final thermalPrinterServiceProvider = Provider<ThermalPrinterService>((ref) {
  return ThermalPrinterService(ref.watch(thermalPrinterTransportProvider));
});

final thermalPrinterSettingsProvider =
    FutureProvider.autoDispose<ThermalPrinterSettings>((ref) async {
  final prefs = ref.watch(prefsProvider);
  return ThermalPrinterSettings.load(prefs);
});
