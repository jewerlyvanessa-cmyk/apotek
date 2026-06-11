import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/admin_repository.dart';

final _branchesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminRepositoryProvider).listBranches();
});

/// Daftar cabang tenant (read-only). Kelola penuh via Super Admin / Platform.
class BranchesPage extends ConsumerWidget {
  const BranchesPage({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final canEditMode = user?.isOwner == true ||
        user?.isTenantWideManager == true ||
        user?.isBranchManager == true;
    final async = ref.watch(_branchesProvider);

    return AppScaffold(
      title: 'Daftar Cabang',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: Text(
              'Perubahan cabang (tambah, edit, aktif/nonaktif) dilakukan oleh Super Admin.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(_err(e))),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('Belum ada cabang'));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(_branchesProvider);
                    await ref.read(_branchesProvider.future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final b = items[index];
                      final active =
                          b['isActive'] == true || b['is_active'] == true;
                      final isCentral =
                          b['isCentralWarehouse'] == true ||
                          b['is_central_warehouse'] == true;
                      final stockMode = b['stockMode']?.toString() ??
                          b['stock_mode']?.toString() ??
                          'SIMPLE';
                      final branchId = b['id']?.toString() ?? '';
                      return Card(
                        child: ListTile(
                          leading: AppIcon3D.list(
                            icon: isCentral ? Icons.warehouse : Icons.store,
                            accentKey: b['name']?.toString() ?? branchId,
                            accent: active ? null : AppColors.textSecondary,
                          ),
                          title: Text(
                            b['name']?.toString() ?? '-',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: active
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                          subtitle: Text(
                            [
                              if (b['code'] != null &&
                                  b['code'].toString().isNotEmpty)
                                'Kode: ${b['code']}',
                              if (b['address'] != null &&
                                  b['address'].toString().isNotEmpty)
                                b['address'].toString(),
                              if (isCentral) 'Gudang pusat',
                              if (stockMode == 'WAREHOUSE_ETALASE')
                                'Gudang + Etalase',
                              if (stockMode == 'SIMPLE' && !isCentral)
                                'Stok sederhana',
                              if (!active) 'Nonaktif',
                            ].join(' · '),
                          ),
                          isThreeLine: true,
                          trailing: canEditMode && !isCentral
                              ? const Icon(Icons.tune)
                              : null,
                          onTap: canEditMode && !isCentral && branchId.isNotEmpty
                              ? () async {
                                  final saved = await context.push<bool>(
                                    '/admin/branches/$branchId/stock-mode',
                                    extra: {
                                      'name': b['name']?.toString() ?? '-',
                                      'stock_mode': stockMode,
                                    },
                                  );
                                  if (saved == true) {
                                    ref.invalidate(_branchesProvider);
                                  }
                                }
                              : null,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
