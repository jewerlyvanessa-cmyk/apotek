import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/paginated_result.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/async_error_view.dart';
import '../../../../shared/widgets/async_loading_view.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../../../shared/widgets/pagination_bar.dart';
import '../../data/platform_repository.dart';

final _branchHubPageProvider = StateProvider.autoDispose<int>((ref) => 1);

final _branchHubTenantsProvider =
    FutureProvider.autoDispose<PaginatedResult<Map<String, dynamic>>>((ref) async {
  final page = ref.watch(_branchHubPageProvider);
  return ref.watch(platformRepositoryProvider).listTenants(page: page);
});

/// Pilih tenant lalu kelola cabang (Super Admin).
class PlatformBranchesHubPage extends ConsumerWidget {
  const PlatformBranchesHubPage({super.key});

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
    final async = ref.watch(_branchHubTenantsProvider);

    return AppScaffold(
      title: 'Kelola Cabang',
      body: async.when(
        loading: () => const AsyncLoadingView(),
        error: (e, _) => AsyncErrorView(
          message: _err(e),
          onRetry: () => ref.invalidate(_branchHubTenantsProvider),
        ),
        data: (result) {
          final items = result.items;
          if (items.isEmpty) {
            return const EmptyStateView(
              title: 'Belum ada tenant',
              subtitle: 'Buat tenant terlebih dahulu',
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
                      ref.read(_branchHubPageProvider.notifier).state = p,
                );
              }
              final t = items[index];
              final id = t['id']?.toString() ?? '';
              final name = t['name']?.toString() ?? '-';
              final code = t['code']?.toString();
              final active = t['isActive'] == true || t['is_active'] == true;
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: AppIcon3D.list(
                    icon: Icons.store,
                    accentKey: name,
                    accent: active ? null : AppColors.textSecondary,
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: active ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text(
                    [
                      if (code != null && code.isNotEmpty) 'Kode: $code',
                      if (!active) 'Nonaktif',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: id.isEmpty
                      ? null
                      : () {
                          final q = Uri(queryParameters: {'name': name});
                          context.push(
                            '/platform/tenants/$id/branches$q',
                          );
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
