import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/async_error_view.dart';
import '../../../../shared/widgets/async_loading_view.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../data/platform_repository.dart';

final _platformBranchesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, tenantId) async {
  return ref.watch(platformRepositoryProvider).listBranches(tenantId: tenantId);
});

class PlatformBranchesPage extends ConsumerStatefulWidget {
  const PlatformBranchesPage({
    super.key,
    required this.tenantId,
    required this.tenantName,
  });

  final String tenantId;
  final String tenantName;

  @override
  ConsumerState<PlatformBranchesPage> createState() =>
      _PlatformBranchesPageState();
}

class _PlatformBranchesPageState extends ConsumerState<PlatformBranchesPage> {
  String _err(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message']?.toString();
        if (msg != null && msg.isNotEmpty) return msg;
      }
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _openCreate() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Cabang'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama cabang'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Kode (opsional)'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Telepon'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Alamat'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                await ref.read(platformRepositoryProvider).createBranch(
                      tenantId: widget.tenantId,
                      name: name,
                      code: codeCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                    );
                ref.invalidate(_platformBranchesProvider(widget.tenantId));
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_err(e)),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEdit(Map<String, dynamic> branch) async {
    final nameCtrl = TextEditingController(text: branch['name']?.toString() ?? '');
    final codeCtrl = TextEditingController(text: branch['code']?.toString() ?? '');
    final addressCtrl =
        TextEditingController(text: branch['address']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: branch['phone']?.toString() ?? '');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Cabang'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama cabang'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Kode'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Telepon'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Alamat'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                await ref.read(platformRepositoryProvider).updateBranch(
                      tenantId: widget.tenantId,
                      branchId: branch['id'] as String,
                      name: name,
                      code: codeCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                    );
                ref.invalidate(_platformBranchesProvider(widget.tenantId));
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_err(e)),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    codeCtrl.dispose();
    addressCtrl.dispose();
    phoneCtrl.dispose();
  }

  Future<void> _toggleCentral(Map<String, dynamic> branch) async {
    final id = branch['id']?.toString();
    if (id == null) return;
    final isCentral =
        branch['isCentralWarehouse'] == true ||
        branch['is_central_warehouse'] == true;
    try {
      await ref.read(platformRepositoryProvider).updateBranch(
            tenantId: widget.tenantId,
            branchId: id,
            isCentralWarehouse: !isCentral,
          );
      ref.invalidate(_platformBranchesProvider(widget.tenantId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_err(e)), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _confirmDeleteBranch(Map<String, dynamic> branch) async {
    final id = branch['id']?.toString();
    if (id == null) return;
    final active = branch['isActive'] == true || branch['is_active'] == true;
    if (!active) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cabang sudah nonaktif')),
      );
      return;
    }

    final isCentral =
        branch['isCentralWarehouse'] == true ||
        branch['is_central_warehouse'] == true;
    if (isCentral) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gudang pusat tidak dapat dihapus. Jadikan cabang lain sebagai gudang pusat terlebih dahulu.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final name = branch['name']?.toString() ?? 'cabang ini';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus cabang?'),
        content: Text(
          'Cabang "$name" akan dinonaktifkan. Data stok dan transaksi tetap tersimpan '
          'dan dapat diaktifkan kembali lewat switch status.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(platformRepositoryProvider).deleteBranch(
            tenantId: widget.tenantId,
            branchId: id,
          );
      ref.invalidate(_platformBranchesProvider(widget.tenantId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cabang dihapus'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_err(e)), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> branch) async {
    final id = branch['id']?.toString();
    if (id == null) return;
    final active = branch['isActive'] == true || branch['is_active'] == true;
    try {
      await ref.read(platformRepositoryProvider).updateBranch(
            tenantId: widget.tenantId,
            branchId: id,
            isActive: !active,
          );
      ref.invalidate(_platformBranchesProvider(widget.tenantId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_err(e)), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_platformBranchesProvider(widget.tenantId));

    return AppScaffold(
      title: 'Kelola Cabang · ${widget.tenantName}',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Cabang Baru'),
      ),
      body: async.when(
        loading: () => const AsyncLoadingView(),
        error: (e, _) => AsyncErrorView(
          message: _err(e),
          onRetry: () =>
              ref.invalidate(_platformBranchesProvider(widget.tenantId)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyStateView(
              title: 'Belum ada cabang',
              icon: Icons.store_mall_directory_outlined,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final b = items[index];
              final active = b['isActive'] == true || b['is_active'] == true;
              final isCentral =
                  b['isCentralWarehouse'] == true ||
                  b['is_central_warehouse'] == true;
              return Card(
                child: ListTile(
                  onTap: () => _openEdit(b),
                  leading: AppIcon3D.list(
                    icon: isCentral ? Icons.warehouse : Icons.store,
                    accentKey: b['name']?.toString() ?? '',
                    accent: active ? null : AppColors.textSecondary,
                  ),
                  title: Text(b['name']?.toString() ?? '-'),
                  subtitle: Text(
                    [
                      if (b['code'] != null && b['code'].toString().isNotEmpty)
                        b['code'].toString(),
                      if (isCentral) 'Gudang pusat',
                      if (!active) 'Nonaktif',
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (active && !isCentral)
                        IconButton(
                          tooltip: 'Hapus cabang',
                          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                          onPressed: () => _confirmDeleteBranch(b),
                        ),
                      IconButton(
                        tooltip: isCentral
                            ? 'Cabut gudang pusat'
                            : 'Jadikan gudang pusat',
                        icon: Icon(
                          isCentral ? Icons.warehouse : Icons.warehouse_outlined,
                          color: isCentral ? AppColors.primary : null,
                        ),
                        onPressed: () => _toggleCentral(b),
                      ),
                      Switch(
                        value: active,
                        onChanged: (_) => _toggleActive(b),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
