import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/paginated_result.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../../shared/widgets/async_error_view.dart';
import '../../../../shared/widgets/async_loading_view.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../../../shared/widgets/pagination_bar.dart';
import '../../data/platform_repository.dart';

final _tenantPageProvider = StateProvider.autoDispose<int>((ref) => 1);

final _tenantsProvider =
    FutureProvider.autoDispose<PaginatedResult<Map<String, dynamic>>>((ref) async {
  final page = ref.watch(_tenantPageProvider);
  return ref.watch(platformRepositoryProvider).listTenants(page: page);
});

class TenantsListPage extends ConsumerStatefulWidget {
  const TenantsListPage({super.key});

  @override
  ConsumerState<TenantsListPage> createState() => _TenantsListPageState();
}

class _TenantsListPageState extends ConsumerState<TenantsListPage> {

  String _subscriptionStatusLabel(String? expiredAt) {
    if (expiredAt == null || expiredAt.isEmpty) return 'Langganan aktif';
    final dt = DateTime.tryParse(expiredAt);
    if (dt == null) return 'Langganan aktif';
    if (dt.isAfter(DateTime.now())) return 'Aktif hingga ${_fmt(dt)}';
    return 'Kedaluwarsa';
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

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

  Future<void> _confirmDeleteTenant({
    required String id,
    required String name,
    required bool active,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(active ? 'Hapus tenant?' : 'Hapus permanen tenant nonaktif?'),
        content: Text(
          active
              ? 'Jika tenant tidak punya cabang, user, obat, order, atau stok, '
                  'akan dihapus permanen. Jika masih ada data bisnis, tenant hanya '
                  'dinonaktifkan (bisa diaktifkan lagi dari halaman edit).'
              : 'Tenant "$name" sudah nonaktif. Jika tidak ada data bisnis tersisa, '
                  'tenant akan dihapus permanen dari database. Tipe produk default '
                  'ikut dibersihkan otomatis.',
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
      final result = await ref.read(platformRepositoryProvider).deleteTenant(id);
      ref.invalidate(_tenantsProvider);
      if (mounted) {
        final msg = result['_apiMessage']?.toString() ??
            (result['permanent'] == true
                ? 'Tenant dihapus permanen'
                : 'Tenant dinonaktifkan');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_tenantsProvider);

    return AppScaffold(
      title: 'Tenant',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<bool>('/platform/tenants/new');
          if (created == true) ref.invalidate(_tenantsProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Tenant Baru'),
      ),
      body: async.when(
        loading: () => const AsyncLoadingView(),
        error: (e, _) => AsyncErrorView(
          message: _err(e),
          onRetry: () => ref.invalidate(_tenantsProvider),
        ),
        data: (result) {
          final items = result.items;
          if (items.isEmpty) {
            return const EmptyStateView(
              title: 'Belum ada tenant',
              icon: Icons.store_outlined,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index == items.length) {
                return PaginationBar(
                  meta: result.meta,
                  onPageChanged: (p) =>
                      ref.read(_tenantPageProvider.notifier).state = p,
                );
              }
              final t = items[index];
              final id = t['id']?.toString() ?? '';
              final name = t['name']?.toString() ?? '-';
              final code = t['code']?.toString() ?? '';
              final active = t['isActive'] == true || t['is_active'] == true;
              final branchCount =
                  (t['_count'] as Map?)?['branches']?.toString() ?? '0';
              final plan = t['subscriptionPlan']?.toString() ??
                  t['subscription_plan']?.toString() ??
                  '—';
              final expiredRaw = t['subscriptionExpiredAt']?.toString() ??
                  t['subscription_expired_at']?.toString();
              final subStatus = _subscriptionStatusLabel(expiredRaw);

              return Card(
                child: ListTile(
                  leading: AppIcon3D.list(
                    icon: Icons.store,
                    accentKey: name,
                    accent: active ? null : AppColors.textSecondary,
                  ),
                  title: Text(name),
                  subtitle: Text(
                    '$code · $branchCount cabang · $plan · $subStatus',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!active)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Text(
                            'Nonaktif',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                      IconButton(
                        tooltip: active ? 'Hapus tenant' : 'Hapus permanen',
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        onPressed: id.isEmpty
                            ? null
                            : () => _confirmDeleteTenant(
                                  id: id,
                                  name: name,
                                  active: active,
                                ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () async {
                    await context.push('/platform/tenants/$id/edit');
                    ref.invalidate(_tenantsProvider);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
