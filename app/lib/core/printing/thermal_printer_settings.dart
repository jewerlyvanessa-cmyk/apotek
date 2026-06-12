import 'package:shared_preferences/shared_preferences.dart';

enum ThermalPrinterMode {
  wifi,
  bluetooth,
}

extension ThermalPrinterModeX on ThermalPrinterMode {
  String get label => switch (this) {
        ThermalPrinterMode.wifi => 'WiFi / LAN',
        ThermalPrinterMode.bluetooth => 'Bluetooth',
      };

  String get storageValue => name;

  static ThermalPrinterMode fromStorage(String? value) {
    return ThermalPrinterMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ThermalPrinterMode.wifi,
    );
  }
}

class ThermalPrinterSettings {
  const ThermalPrinterSettings({
    required this.mode,
    required this.host,
    required this.port,
    this.bluetoothAddress,
    this.bluetoothName,
  });

  final ThermalPrinterMode mode;
  final String host;
  final int port;
  final String? bluetoothAddress;
  final String? bluetoothName;

  bool get isWifi => mode == ThermalPrinterMode.wifi;
  bool get isBluetooth => mode == ThermalPrinterMode.bluetooth;

  bool get isConfigured => switch (mode) {
        ThermalPrinterMode.wifi => host.trim().isNotEmpty && port > 0,
        ThermalPrinterMode.bluetooth =>
          bluetoothAddress != null && bluetoothAddress!.trim().isNotEmpty,
      };

  static const _keyMode = 'printer_mode';
  static const _keyHost = 'printer_host';
  static const _keyPort = 'printer_port';
  static const _keyBtAddress = 'printer_bt_address';
  static const _keyBtName = 'printer_bt_name';

  static ThermalPrinterSettings defaults() {
    return const ThermalPrinterSettings(
      mode: ThermalPrinterMode.wifi,
      host: '192.168.0.100',
      port: 9100,
    );
  }

  static Future<ThermalPrinterSettings> load(SharedPreferences prefs) async {
    final defaults = ThermalPrinterSettings.defaults();
    return ThermalPrinterSettings(
      mode: ThermalPrinterModeX.fromStorage(prefs.getString(_keyMode)),
      host: prefs.getString(_keyHost) ?? defaults.host,
      port: prefs.getInt(_keyPort) ?? defaults.port,
      bluetoothAddress: prefs.getString(_keyBtAddress),
      bluetoothName: prefs.getString(_keyBtName),
    );
  }

  static Future<void> save(
    SharedPreferences prefs, {
    required ThermalPrinterMode mode,
    required String host,
    required int port,
    String? bluetoothAddress,
    String? bluetoothName,
  }) async {
    await prefs.setString(_keyMode, mode.storageValue);
    await prefs.setString(_keyHost, host);
    await prefs.setInt(_keyPort, port);
    if (bluetoothAddress != null && bluetoothAddress.isNotEmpty) {
      await prefs.setString(_keyBtAddress, bluetoothAddress);
    } else {
      await prefs.remove(_keyBtAddress);
    }
    if (bluetoothName != null && bluetoothName.isNotEmpty) {
      await prefs.setString(_keyBtName, bluetoothName);
    } else {
      await prefs.remove(_keyBtName);
    }
  }
}
