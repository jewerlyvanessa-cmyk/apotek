import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../data/setup_repository.dart';
import '../providers/setup_provider.dart';

class DatabaseSetupPage extends ConsumerStatefulWidget {
  const DatabaseSetupPage({super.key, this.initialSetup = false});

  /// Wizard instalasi pertama (tanpa login).
  final bool initialSetup;

  @override
  ConsumerState<DatabaseSetupPage> createState() => _DatabaseSetupPageState();
}

class _DatabaseSetupPageState extends ConsumerState<DatabaseSetupPage> {
  final _hostCtrl = TextEditingController(text: '127.0.0.1');
  final _portCtrl = TextEditingController(text: '5432');
  final _dbCtrl = TextEditingController(text: 'apotikflow');
  final _adminUserCtrl = TextEditingController(text: 'postgres');
  final _adminPassCtrl = TextEditingController();
  final _appUserCtrl = TextEditingController(text: 'apotikflow_app');
  final _appPassCtrl = TextEditingController(text: 'apotikflow_app_secret');
  final _platformUserCtrl = TextEditingController(text: 'apotikflow_platform');
  final _platformPassCtrl =
      TextEditingController(text: 'apotikflow_platform_secret');

  bool _loading = false;
  String? _log;

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _dbCtrl.dispose();
    _adminUserCtrl.dispose();
    _adminPassCtrl.dispose();
    _appUserCtrl.dispose();
    _appPassCtrl.dispose();
    _platformUserCtrl.dispose();
    _platformPassCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _payload() {
    return {
      'host': _hostCtrl.text.trim(),
      'port': int.tryParse(_portCtrl.text.trim()) ?? 5432,
      'database': _dbCtrl.text.trim(),
      'user': _adminUserCtrl.text.trim(),
      'password': _adminPassCtrl.text,
      'admin_user': _adminUserCtrl.text.trim(),
      'admin_password': _adminPassCtrl.text,
      'app_user': _appUserCtrl.text.trim(),
      'app_password': _appPassCtrl.text,
      'platform_user': _platformUserCtrl.text.trim(),
      'platform_password': _platformPassCtrl.text,
      'migrate_user': _adminUserCtrl.text.trim(),
      'migrate_password': _adminPassCtrl.text,
    };
  }

  String _err(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message']?.toString();
        if (msg != null && msg.isNotEmpty) return msg;
        final output = data['output']?.toString();
        if (output != null && output.isNotEmpty) return output;
      }
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  void _showResult(String message, {bool success = true}) {
    setState(() => _log = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.danger,
      ),
    );
  }

  Future<void> _test() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(setupRepositoryProvider).testConnection({
        'host': _hostCtrl.text.trim(),
        'port': int.tryParse(_portCtrl.text.trim()) ?? 5432,
        'database': _dbCtrl.text.trim(),
        'user': _adminUserCtrl.text.trim(),
        'password': _adminPassCtrl.text,
      });
      _showResult(
        res['message']?.toString() ?? 'Selesai',
        success: res['ok'] == true,
      );
    } catch (e) {
      _showResult(_err(e), success: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createDb() async {
    setState(() => _loading = true);
    try {
      final res =
          await ref.read(setupRepositoryProvider).createDatabase(_payload());
      _showResult(res['message']?.toString() ?? 'Database dibuat');
      ref.invalidate(setupStatusProvider);
    } catch (e) {
      _showResult(_err(e), success: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _migrate() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(setupRepositoryProvider).runMigrate(_payload());
      final output = res['output']?.toString();
      _showResult(
        output != null && output.isNotEmpty
            ? '${res['message']}\n$output'
            : res['message']?.toString() ?? 'Migrasi selesai',
      );
      ref.invalidate(setupStatusProvider);
    } catch (e) {
      _showResult(_err(e), success: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showRestartDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.restart_alt, color: AppColors.primary),
        title: const Text('Restart service API'),
        content: const Text(
          'Konfigurasi database disimpan. Restart backend agar koneksi baru aktif.\n\n'
          'Linux (systemd):\n'
          '  sudo systemctl restart apotikflow-api\n\n'
          'Manual:\n'
          '  node dist/main\n\n'
          'Docker:\n'
          '  docker compose -f docker-compose.prod.yml restart api',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Future<void> _apply() async {
    setState(() => _loading = true);
    try {
      final res =
          await ref.read(setupRepositoryProvider).applyConfig(_payload());
      final restartRequired = res['restart_required'] == true;
      _showResult(res['message']?.toString() ?? 'Konfigurasi diterapkan');
      ref.invalidate(setupStatusProvider);
      ref.invalidate(databaseConfigProvider);
      if (restartRequired) {
        await _showRestartDialog();
      }
    } catch (e) {
      _showResult(_err(e), success: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.md),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(setupStatusProvider);

    return AppScaffold(
      title: widget.initialSetup ? 'Instalasi Database' : 'Pengaturan Database',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          statusAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(
              'Status: ${_err(e)}',
              style: const TextStyle(color: AppColors.danger),
            ),
            data: (s) {
              final configured = s['database_configured'] == true;
              final schemaReady = s['schema_ready'] == true;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        configured
                            ? (schemaReady
                                ? 'Database terhubung & schema siap'
                                : 'Database terhubung — migrasi belum dijalankan')
                            : 'Database belum terhubung',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (s['database_message'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            s['database_message'].toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Khusus paket beli putus on-prem. PostgreSQL harus sudah berjalan di server.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          _section('Lokasi PostgreSQL'),
          TextField(
            controller: _hostCtrl,
            decoration: const InputDecoration(
              labelText: 'Host',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _portCtrl,
            decoration: const InputDecoration(
              labelText: 'Port',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _dbCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama database',
              border: OutlineInputBorder(),
            ),
          ),
          _section('Akun admin (buat database & migrasi)'),
          TextField(
            controller: _adminUserCtrl,
            decoration: const InputDecoration(
              labelText: 'User admin (mis. postgres)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _adminPassCtrl,
            decoration: const InputDecoration(
              labelText: 'Password admin',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          _section('Role aplikasi (disarankan default)'),
          TextField(
            controller: _appUserCtrl,
            decoration: const InputDecoration(
              labelText: 'User API umum',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _appPassCtrl,
            decoration: const InputDecoration(
              labelText: 'Password API umum',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _platformUserCtrl,
            decoration: const InputDecoration(
              labelText: 'User Super Admin platform',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _platformPassCtrl,
            decoration: const InputDecoration(
              labelText: 'Password Super Admin platform',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: _loading ? null : _test,
                icon: const Icon(Icons.link),
                label: const Text('Tes koneksi'),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _createDb,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Buat database'),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _migrate,
                icon: const Icon(Icons.schema_outlined),
                label: const Text('Migrasi schema'),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : _apply,
                icon: const Icon(Icons.save),
                label: const Text('Terapkan & simpan'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Urutan: Tes koneksi → Buat database (jika baru) → Migrasi schema → Terapkan & simpan → restart API.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (_log != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _log!,
              style: const TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            AppButton(
              label: 'Segarkan status',
              onPressed: () => ref.invalidate(setupStatusProvider),
            ),
        ],
      ),
    );
  }
}
