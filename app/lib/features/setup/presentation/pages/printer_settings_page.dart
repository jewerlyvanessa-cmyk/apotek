import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/printing/printer_providers.dart';
import '../../../../core/printing/thermal_printer_settings.dart';
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
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = ref.read(prefsProvider);
    final settings = await ThermalPrinterSettings.load(prefs);
    if (!mounted) return;
    setState(() {
      _hostCtrl.text = settings.host;
      _portCtrl.text = settings.port.toString();
      _loading = false;
    });
  }

  int? _parsePort() {
    return int.tryParse(_portCtrl.text.trim());
  }

  Future<void> _save() async {
    final host = _hostCtrl.text.trim();
    final port = _parsePort();
    if (host.isEmpty || port == null || port <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi alamat IP/host dan port printer (mis. 9100)'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final prefs = ref.read(prefsProvider);
      await ThermalPrinterSettings.save(prefs, host: host, port: port);
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

  Future<void> _testPrint() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cetak thermal tidak tersedia di web'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final host = _hostCtrl.text.trim();
    final port = _parsePort();
    if (host.isEmpty || port == null || port <= 0) return;

    setState(() => _testing = true);
    try {
      final cfg = ref.read(appConfigProvider);
      await ref.read(thermalPrinterServiceProvider).printTestPage(
            host: host,
            port: port,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal uji cetak: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Printer Thermal',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const Text(
                  'Printer struk jaringan (ESC/POS, port 9100). '
                  'Pastikan perangkat dan printer berada di jaringan WiFi/LAN yang sama.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
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
