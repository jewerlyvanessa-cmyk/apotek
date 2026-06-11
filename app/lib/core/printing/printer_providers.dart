import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'thermal_printer_service.dart';
import 'thermal_printer_settings.dart';

final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefsProvider must be overridden');
});

final thermalPrinterServiceProvider = Provider<ThermalPrinterService>((ref) {
  return ThermalPrinterService();
});

final thermalPrinterSettingsProvider =
    FutureProvider.autoDispose<ThermalPrinterSettings>((ref) async {
  final prefs = ref.watch(prefsProvider);
  return ThermalPrinterSettings.load(prefs);
});

