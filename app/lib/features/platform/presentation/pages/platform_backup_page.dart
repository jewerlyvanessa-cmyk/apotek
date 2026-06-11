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
import '../../data/platform_repository.dart';

final _backupTenantsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final result = await ref.watch(platformRepositoryProvider).listTenants(
        limit: 100,
      );
  return result.items;
});

class PlatformBackupPage extends ConsumerStatefulWidget {
  const PlatformBackupPage({super.key});

  @override
  ConsumerState<PlatformBackupPage> createState() => _PlatformBackupPageState();
}

class _PlatformBackupPageState extends ConsumerState<PlatformBackupPage> {
  static const _scopeTenant = 'tenant';
  static const _scopeBranch = 'branch';

  String _scope = _scopeTenant;
  String? _tenantId;
  String? _branchId;
  List<Map<String, dynamic>> _branches = [];
  bool _loadingBranches = false;
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

  Future<void> _loadBranches(String tenantId) async {
    setState(() {
      _loadingBranches = true;
      _branchId = null;
      _branches = [];
    });
    try {
      final items = await ref
          .read(platformRepositoryProvider)
          .listBranches(tenantId: tenantId);
      if (mounted) {
        setState(() {
          _branches = items;
          if (items.length == 1) {
            _branchId = items.first['id']?.toString();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingBranches = false);
    }
  }

  String _filename() {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    if (_scope == _scopeTenant) {
      final code = _selectedTenantCode() ?? 'tenant';
      return 'backup_tenant_${code}_$stamp.json';
    }
    final code = _selectedBranchCode() ?? 'cabang';
    return 'backup_cabang_${code}_$stamp.json';
  }

  String? _selectedTenantCode() {
    if (_tenantId == null) return null;
    final tenants = ref.read(_backupTenantsProvider).valueOrNull ?? [];
    for (final t in tenants) {
      if (t['id']?.toString() == _tenantId) {
        return t['code']?.toString();
      }
    }
    return null;
  }

  String? _selectedBranchCode() {
    if (_branchId == null) return null;
    for (final b in _branches) {
      if (b['id']?.toString() == _branchId) {
        return b['code']?.toString() ?? b['name']?.toString();
      }
    }
    return null;
  }

  Future<void> _exportBackup() async {
    if (_tenantId == null) {
      _showMsg('Pilih tenant terlebih dahulu');
      return;
    }
    if (_scope == _scopeBranch && _branchId == null) {
      _showMsg('Pilih cabang terlebih dahulu');
      return;
    }

    setState(() {
      _exporting = true;
      _lastSummary = null;
      _lastSavedPath = null;
    });

    try {
      final repo = ref.read(platformRepositoryProvider);
      final Map<String, dynamic> payload;
      if (_scope == _scopeTenant) {
        payload = await repo.backupTenant(_tenantId!);
      } else {
        payload = await repo.backupBranch(
          tenantId: _tenantId!,
          branchId: _branchId!,
        );
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
        files: [XFile(file.path, mimeType: 'application/json', name: file.name)],
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
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
    final tenantsAsync = ref.watch(_backupTenantsProvider);
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');

    return AppScaffold(
      title: 'Backup Data Lokal',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Ekspor data ke file JSON di penyimpanan lokal perangkat. Password user tidak disertakan.',
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
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: _scopeTenant,
                label: Text('Per Tenant'),
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
                _branchId = null;
                _lastSummary = null;
              });
              if (_scope == _scopeBranch &&
                  _tenantId != null &&
                  _branches.isEmpty) {
                _loadBranches(_tenantId!);
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          tenantsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Gagal memuat tenant: $e'),
            data: (tenants) {
              if (tenants.isEmpty) {
                return const Text('Belum ada tenant');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _tenantId,
                    decoration: const InputDecoration(
                      labelText: 'Tenant',
                      border: OutlineInputBorder(),
                    ),
                    items: tenants
                        .map(
                          (t) => DropdownMenuItem(
                            value: t['id']?.toString(),
                            child: Text(
                              '${t['name']} (${t['code']})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      setState(() {
                        _tenantId = id;
                        _branchId = null;
                        _branches = [];
                        _lastSummary = null;
                      });
                      if (id != null && _scope == _scopeBranch) {
                        _loadBranches(id);
                      }
                    },
                  ),
                  if (_scope == _scopeBranch) ...[
                    const SizedBox(height: AppSpacing.md),
                    if (_loadingBranches)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_tenantId == null)
                      const Text('Pilih tenant untuk memuat daftar cabang')
                    else if (_branches.isEmpty)
                      const Text('Tenant ini belum memiliki cabang')
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _branchId,
                        decoration: const InputDecoration(
                          labelText: 'Cabang',
                          border: OutlineInputBorder(),
                        ),
                        items: _branches
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
                      ),
                  ],
                ],
              );
            },
          ),
          if (_lastSummary != null) ...[
            const SizedBox(height: AppSpacing.lg),
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
          ],
          const SizedBox(height: AppSpacing.xl),
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
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
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
