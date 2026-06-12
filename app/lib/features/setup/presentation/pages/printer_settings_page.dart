import 'dart:async';

import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/printing/printer_providers.dart';
import '../../../../core/printing/thermal_printer_settings.dart';
import '../../../../core/printing/thermal_printer_transport.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/components/app_text_field.dart';
import '../../../../shared/layouts/app_scaffold.dart';

class PrinterSettingsPage extends ConsumerStatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  ConsumerState<PrinterSettingsPage> createState() =>
      _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends ConsumerState<PrinterSettingsPage> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '9100');

  ThermalPrinterMode _mode = ThermalPrinterMode.wifi;
  String? _bluetoothAddress;
  String? _bluetoothName;
  List<PrinterBluetooth> _scanResults = [];
  bool _scanning = false;
  StreamSubscription<List<PrinterBluetooth>>? _scanSub;
  StreamSubscription<bool>? _scanningSub;

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  PrinterBluetoothManager? _bluetoothManager;

  PrinterBluetoothManager get bluetoothManager {
    _bluetoothManager ??= ref.read(printerBluetoothManagerProvider);
    return _bluetoothManager!;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _scanningSub?.cancel();
    _bluetoothManager?.stopScan();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = ref.read(prefsProvider);
    final settings = await ThermalPrinterSettings.load(prefs);
    if (!mounted) return;
    setState(() {
      _mode = settings.mode;
      _hostCtrl.text = settings.host;
      _portCtrl.text = settings.port.toString();
      _bluetoothAddress = settings.bluetoothAddress;
      _bluetoothName = settings.bluetoothName;
      _loading = false;
    });
  }

  int? _parsePort() => int.tryParse(_portCtrl.text.trim());

  ThermalPrinterSettings _currentSettings() {
    return ThermalPrinterSettings(
      mode: _mode,
      host: _hostCtrl.text.trim(),
      port: _parsePort() ?? 9100,
      bluetoothAddress: _bluetoothAddress,
      bluetoothName: _bluetoothName,
    );
  }

  Future<void> _save() async {
    final settings = _currentSettings();
    if (_mode == ThermalPrinterMode.wifi) {
      if (settings.host.isEmpty || settings.port <= 0) {
        _showError('Isi alamat IP/host dan port printer (mis. 9100)');
        return;
      }
    } else if (_bluetoothAddress == null || _bluetoothAddress!.isEmpty) {
      _showError('Pilih printer Bluetooth terlebih dahulu');
      return;
    }

    setState(() => _saving = true);
    try {
      final prefs = ref.read(prefsProvider);
      await ThermalPrinterSettings.save(
        prefs,
        mode: settings.mode,
        host: settings.host,
        port: settings.port,
        bluetoothAddress: settings.bluetoothAddress,
        bluetoothName: settings.bluetoothName,
      );
      ref.invalidate(thermalPrinterSettingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan printer disimpan'),
          backgroundColor: AppColors.success,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  void _startBluetoothScan() {
    if (kIsWeb || !thermalBluetoothSupported) {
      _showError('Bluetooth hanya tersedia di aplikasi Android/iOS');
      return;
    }

    final manager = bluetoothManager;
    _scanSub?.cancel();
    _scanningSub?.cancel();

    setState(() {
      _scanResults = [];
      _scanning = true;
    });

    _scanSub = manager.scanResults.listen((devices) {
      if (!mounted) return;
      setState(() => _scanResults = devices);
    });
    _scanningSub = manager.isScanningStream.listen((scanning) {
      if (!mounted) return;
      setState(() => _scanning = scanning);
    });

    manager.startScan(const Duration(seconds: 6));
  }

  void _selectBluetoothPrinter(PrinterBluetooth printer) {
    bluetoothManager.selectPrinter(printer);
    setState(() {
      _bluetoothAddress = printer.address;
      _bluetoothName = printer.name ?? printer.address;
    });
  }

  Future<void> _testPrint() async {
    if (kIsWeb) {
      _showError('Cetak thermal tidak tersedia di web');
      return;
    }

    final settings = _currentSettings();
    if (!settings.isConfigured) {
      _showError('Lengkapi pengaturan printer terlebih dahulu');
      return;
    }

    setState(() => _testing = true);
    try {
      final cfg = ref.read(appConfigProvider);
      await ref.read(thermalPrinterServiceProvider).printTestPage(
            settings: settings,
            appName: cfg.appName,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Halaman uji terkirim ke printer'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) _showError('Gagal uji cetak: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final btSupported = thermalBluetoothSupported;

    return AppScaffold(
      title: 'Printer Thermal',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const Text(
                  'Printer struk ESC/POS 58 mm. Pilih koneksi WiFi/LAN atau Bluetooth.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                SegmentedButton<ThermalPrinterMode>(
                  segments: [
                    const ButtonSegment(
                      value: ThermalPrinterMode.wifi,
                      label: Text('WiFi / LAN'),
                      icon: Icon(Icons.wifi),
                    ),
                    ButtonSegment(
                      value: ThermalPrinterMode.bluetooth,
                      label: const Text('Bluetooth'),
                      icon: const Icon(Icons.bluetooth),
                      enabled: btSupported,
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) {
                    setState(() => _mode = selection.first);
                  },
                ),
                if (!btSupported) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Mode Bluetooth hanya di aplikasi Android/iOS (bukan web/desktop).',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (_mode == ThermalPrinterMode.wifi) ...[
                  AppTextField(
                    controller: _hostCtrl,
                    label: 'Alamat IP / host',
                    prefixIcon: Icons.router_outlined,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _portCtrl,
                    label: 'Port',
                    prefixIcon: Icons.settings_ethernet_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Pastikan tablet/HP dan printer di jaringan WiFi/LAN yang sama. Port umum: 9100.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ] else ...[
                  if (_bluetoothAddress != null) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.bluetooth_connected),
                        title: Text(_bluetoothName ?? _bluetoothAddress!),
                        subtitle: Text(_bluetoothAddress!),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _bluetoothAddress = null;
                            _bluetoothName = null;
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  OutlinedButton.icon(
                    onPressed: _scanning ? null : _startBluetoothScan,
                    icon: _scanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bluetooth_searching),
                    label: Text(_scanning ? 'Mencari...' : 'Cari printer Bluetooth'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Nyalakan printer, aktifkan Bluetooth, lalu pilih perangkat dari daftar.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (_scanResults.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    ..._scanResults.map((printer) {
                      final selected = printer.address == _bluetoothAddress;
                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        color: selected
                            ? AppColors.primaryContainer.withValues(alpha: 0.35)
                            : null,
                        child: ListTile(
                          leading: Icon(
                            selected ? Icons.check_circle : Icons.print_outlined,
                            color: selected ? AppColors.primary : null,
                          ),
                          title: Text(printer.name ?? 'Printer'),
                          subtitle: Text(printer.address ?? '-'),
                          onTap: () => _selectBluetoothPrinter(printer),
                        ),
                      );
                    }),
                  ],
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Simpan',
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!kIsWeb)
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _testPrint,
                    icon: _testing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined),
                    label: const Text('Uji cetak'),
                  ),
              ],
            ),
    );
  }
}
