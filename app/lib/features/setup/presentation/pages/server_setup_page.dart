import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/config/update_server_url.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/printing/printer_providers.dart';
import '../../../../core/storage/server_url_storage.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/layouts/app_scaffold.dart';

class ServerSetupPage extends ConsumerStatefulWidget {
  const ServerSetupPage({super.key});

  @override
  ConsumerState<ServerSetupPage> createState() => _ServerSetupPageState();
}

class _ServerSetupPageState extends ConsumerState<ServerSetupPage> {
  final _urlCtrl = TextEditingController();
  bool _loading = false;
  String? _testMessage;
  bool? _testOk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrent());
  }

  void _loadCurrent() {
    final prefs = ref.read(prefsProvider);
    final saved = ServerUrlStorage(prefs).savedApiBaseUrl;
    final config = ref.read(appConfigProvider);
    final display = saved != null && saved.isNotEmpty
        ? wsBaseUrlFromApi(saved)
        : wsBaseUrlFromApi(config.apiBaseUrl);
    _urlCtrl.text = display;
    setState(() {});
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final base = normalizeApiBaseUrl(_urlCtrl.text);
    if (base.isEmpty) return;
    setState(() {
      _loading = true;
      _testMessage = null;
      _testOk = null;
    });
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final res = await dio.get<Map<String, dynamic>>('$base/health');
      final ok = res.data?['success'] == true;
      setState(() {
        _testOk = ok;
        _testMessage = ok
            ? 'Server merespons — ${res.data?['data']?['service'] ?? 'OK'}'
            : 'Server tidak mengembalikan respons valid';
      });
    } catch (e) {
      final hint = e is DioException &&
              (e.type == DioExceptionType.connectionError ||
                  e.type == DioExceptionType.unknown)
          ? '\nPastikan API sudah jalan (cd api && npm run start:dev) '
              'dan URL benar, mis. http://localhost:3000'
          : '';
      setState(() {
        _testOk = false;
        _testMessage = e is DioException
            ? '${e.message ?? 'Tidak dapat terhubung ke server'}$hint'
            : e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final base = normalizeApiBaseUrl(_urlCtrl.text);
    if (base.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alamat server wajib diisi'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final wasLoggedIn = ref.read(authProvider).isAuthenticated;
      final prefs = ref.read(prefsProvider);
      await applyServerApiBaseUrl(ref, prefs, _urlCtrl.text);

      if (wasLoggedIn) {
        await ref.read(authProvider.notifier).logout();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasLoggedIn
                ? 'Alamat server diperbarui. Silakan login ulang ke server baru.'
                : 'Alamat server disimpan. Anda dapat login ke server tersebut.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/login');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetToDefault() async {
    final prefs = ref.read(prefsProvider);
    await ServerUrlStorage(prefs).clear();
    _loadCurrent();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kembali ke alamat bawaan build. Mulai ulang jika perlu.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(appConfigProvider).apiBaseUrl;
    final isLoggedIn = ref.watch(authProvider).isAuthenticated;

    return AppScaffold(
      title: 'Alamat Server API',
      showLogout: isLoggedIn,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Server aktif saat ini',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wsBaseUrlFromApi(current),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isLoggedIn
                ? 'Jika server pindah IP/host, ubah alamat di bawah lalu simpan. '
                    'Anda akan logout otomatis dan perlu login ulang.'
                : 'Untuk instalasi beli putus on-prem, arahkan aplikasi ke server API di jaringan Anda.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'URL server baru',
              hintText: 'http://192.168.1.10:3000',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          if (_testMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _testMessage!,
              style: TextStyle(
                color: _testOk == true ? AppColors.success : AppColors.danger,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _loading ? null : _test,
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('Tes koneksi'),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Simpan alamat server',
            isLoading: _loading,
            onPressed: _save,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _loading ? null : _resetToDefault,
            child: const Text('Kembalikan alamat bawaan build'),
          ),
        ],
      ),
    );
  }
}
