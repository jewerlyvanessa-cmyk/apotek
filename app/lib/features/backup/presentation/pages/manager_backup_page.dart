import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/backup/local_backup_storage.dart';
import '../../../../shared/components/app_button.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../admin/data/admin_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/backup_repository.dart';

final _managerBranchesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminRepositoryProvider).listBranches();
});

class ManagerBackupPage extends ConsumerStatefulWidget {
  const ManagerBackupPage({super.key});

  @override
  ConsumerState<ManagerBackupPage> createState() => _ManagerBackupPageState();
}

class _ManagerBackupPageState extends ConsumerState<ManagerBackupPage> {
  static const _scopeTenant = 'tenant';
  static const _scopeBranch = 'branch';

  String _scope = _scopeBranch;
  String? _branchId;
  bool _exporting = false;
  Map<String, dynamic>? _lastSummary;
  String? _lastSavedPath;
  String? _storageLabel;
  List<LocalBackupFile> _localFiles = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshLocalList());
  }

  bool get _isTenantWide {
    final user = ref.read(authProvider).user;
    return user?.isTenantWideManager ?? false;
  }

  Future<void> _refreshLocalList() async {
    final storage = await LocalBackupStorage.create();
    final label = await storage.backupsDirectoryLabel();
    final files = await storage.list();
    if (mounted) {
      setState(() {
        _storageLabel = label;
        _localFiles = files;
      });
    }
  }

  String _filename() {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final user = ref.read(authProvider).user;
    if (_scope == _scopeTenant) {
      final code = user?.tenantName?.replaceAll(RegExp(r'\s+'), '_') ?? 'tenant';
      return 'backup_tenant_${code}_$stamp.json';
    }
    final branchLabel = _selectedBranchLabel() ?? user?.branchName ?? 'cabang';
    final safe = branchLabel.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
    return 'backup_cabang_${safe}_$stamp.json';
  }

  String? _selectedBranchLabel() {
    if (_branchId == null) return null;
    final branches = ref.read(_managerBranchesProvider).valueOrNull ?? [];
    for (final b in branches) {
      if (b['id']?.toString() == _branchId) {
        return b['code']?.toString() ?? b['name']?.toString();
      }
    }
    return null;
  }

  Future<void> _exportBackup() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (_scope == _scopeBranch) {
      final branchId = _isTenantWide ? _branchId : user.branchId;
      if (branchId == null || branchId.isEmpty) {
        _showMsg('Pilih cabang terlebih dahulu');
        return;
      }
    }

    setState(() {
      _exporting = true;
      _lastSummary = null;
      _lastSavedPath = null;
    });

    try {
      final repo = ref.read(backupRepositoryProvider);
      final Map<String, dynamic> payload;
      if (_scope == _scopeTenant) {
        payload = await repo.backupTenant();
      } else {
        final branchId = _isTenantWide ? _branchId : user.branchId;
        payload = await repo.backupBranch(branchId: branchId);
      }

      final jsonText = const JsonEncoder.withIndent('  ').convert(payload);
      final name = _filename();

      final storage = await LocalBackupStorage.create();
      final path = await storage.save(filename: name, content: jsonText);

      if (!mounted) return;

      setState(() {
        _lastSummary = payload['summary'] as Map<String, dynamic>?;
        _lastSavedPath = path;
      });
      await _refreshLocalList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                  ? 'Backup disimpan ke folder Download'
                  : 'Backup disimpan secara lokal',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareLocalFile(LocalBackupFile file) async {
    if (kIsWeb) {
      _showMsg('Pada web, buka file dari folder Download');
      return;
    }
    final storage = await LocalBackupStorage.create();
    final content = await storage.readContent(file.path);
    if (content == null || !mounted) {
      _showMsg('File tidak ditemukan');
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(file.path, mimeType: 'application/json', name: file.name),
        ],
        text: 'Backup ApotikFlow — ${file.name}',
      ),
    );
  }

  Future<void> _deleteLocalFile(LocalBackupFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus backup?'),
        content: Text(file.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final storage = await LocalBackupStorage.create();
    await storage.delete(file.path, file.name);
    await _refreshLocalList();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup dihapus')),
      );
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final branchesAsync = ref.watch(_managerBranchesProvider);
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');
    final tenantWide = _isTenantWide;

    if (!tenantWide && user?.branchId != null) {
      _branchId ??= user!.branchId;
    }

    return AppScaffold(
      title: 'Backup Data Lokal',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            tenantWide
                ? 'Ekspor data tenant atau cabang ke file JSON di penyimpanan lokal. Password user tidak disertakan.'
                : 'Ekspor data cabang ${user?.branchName ?? ''} ke file JSON di penyimpanan lokal. Password user tidak disertakan.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          if (_storageLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Lokasi: $_storageLabel',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (tenantWide) ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: _scopeTenant,
                  label: Text('Seluruh Tenant'),
                  icon: Icon(Icons.apartment),
                ),
                ButtonSegment(
                  value: _scopeBranch,
                  label: Text('Per Cabang'),
                  icon: Icon(Icons.store),
                ),
              ],
              selected: {_scope},
              onSelectionChanged: (v) {
                setState(() {
                  _scope = v.first;
                  _lastSummary = null;
                });
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (!tenantWide || _scope == _scopeBranch) ...[
            if (tenantWide)
              branchesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Gagal memuat cabang: $e'),
                data: (branches) {
                  if (branches.isEmpty) {
                    return const Text('Belum ada cabang');
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _branchId,
                    decoration: const InputDecoration(
                      labelText: 'Cabang',
                      border: OutlineInputBorder(),
                    ),
                    items: branches
                        .map(
                          (b) => DropdownMenuItem(
                            value: b['id']?.toString(),
                            child: Text(
                              b['name']?.toString() ?? '-',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) => setState(() {
                      _branchId = id;
                      _lastSummary = null;
                    }),
                  );
                },
              )
            else
              Card(
                child: ListTile(
                  leading: AppIcon3D.list(
                    icon: Icons.store_outlined,
                    accentKey: user?.branchName ?? 'branch',
                  ),
                  title: Text(user?.branchName ?? 'Cabang Anda'),
                  subtitle: const Text('Backup mencakup data cabang ini'),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (_lastSummary != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ringkasan backup terakhir',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (_lastSavedPath != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _lastSavedPath!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    ..._lastSummary!.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('${e.key}: ${e.value}'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppButton(
            label: _exporting ? 'Membuat backup...' : 'Simpan Backup Lokal',
            onPressed: _exporting ? null : _exportBackup,
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Text(
                'Backup tersimpan',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Muat ulang',
                onPressed: _refreshLocalList,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_localFiles.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text('Belum ada file backup lokal'),
              ),
            )
          else
            ..._localFiles.map(
              (f) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: AppIcon3D.list(
                    icon: Icons.insert_drive_file_outlined,
                    accentKey: f.name,
                  ),
                  title: Text(
                    f.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${dateFmt.format(f.modifiedAt)} · ${_formatSize(f.sizeBytes)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!kIsWeb)
                        IconButton(
                          tooltip: 'Bagikan',
                          icon: const Icon(Icons.share_outlined),
                          onPressed: () => _shareLocalFile(f),
                        ),
                      IconButton(
                        tooltip: 'Hapus',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.danger,
                        ),
                        onPressed: () => _deleteLocalFile(f),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
