import 'package:shared_preferences/shared_preferences.dart';

class ThermalPrinterSettings {
  const ThermalPrinterSettings({
    required this.host,
    required this.port,
  });

  final String host;
  final int port;

  static const _keyHost = 'printer_host';
  static const _keyPort = 'printer_port';

  static ThermalPrinterSettings defaults() {
    return const ThermalPrinterSettings(host: '192.168.0.100', port: 9100);
  }

  static Future<ThermalPrinterSettings> load(SharedPreferences prefs) async {
    final host = prefs.getString(_keyHost) ?? defaults().host;
    final port = prefs.getInt(_keyPort) ?? defaults().port;
    return ThermalPrinterSettings(host: host, port: port);
  }

  static Future<void> save(
    SharedPreferences prefs, {
    required String host,
    required int port,
  }) async {
    await prefs.setString(_keyHost, host);
    await prefs.setInt(_keyPort, port);
  }
}

