import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/async_error_view.dart';
import '../../../../shared/widgets/async_loading_view.dart';
import '../../../../shared/widgets/empty_state_view.dart';

final procurementListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get<Map<String, dynamic>>(
    '/procurements',
    queryParameters: {'limit': 30},
  );
  final list = (res.data?['data'] as List?) ?? [];
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

class ProcurementPage extends ConsumerWidget {
  const ProcurementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(procurementListProvider);

    return AppScaffold(
      title: 'Pengadaan Gudang Pusat',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<bool>('/procurements/new');
          if (created == true) {
            ref.invalidate(procurementListProvider);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Pengadaan Baru'),
      ),
      body: listAsync.when(
        loading: () => const AsyncLoadingView(),
        error: (e, _) => AsyncErrorView.fromError(
          e,
          onRetry: () => ref.invalidate(procurementListProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyStateView(
              title: 'Belum ada pengadaan',
              subtitle: 'Tap + untuk membuat draft pengadaan baru.',
              icon: Icons.local_shipping_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(procurementListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final p = items[index];
                final status = p['status']?.toString() ?? '-';
                final id = p['id']?.toString() ?? '';
                return Card(
                  child: ListTile(
                    title: Text(
                      p['procurementNumber']?.toString() ?? id,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('Status: $status'),
                    trailing: status == 'DRAFT'
                        ? PopupMenuButton<String>(
                            onSelected: (action) async {
                              try {
                                if (action == 'complete') {
                                  await ref.read(dioProvider).post(
                                        '/procurements/$id/complete',
                                      );
                                } else if (action == 'cancel') {
                                  await ref.read(dioProvider).post(
                                        '/procurements/$id/cancel',
                                      );
                                }
                                ref.invalidate(procurementListProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        action == 'complete'
                                            ? 'Pengadaan selesai — stok masuk gudang pusat'
                                            : 'Pengadaan dibatalkan',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$e'),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'complete',
                                child: Text('Selesaikan (posting stok)'),
                              ),
                              PopupMenuItem(
                                value: 'cancel',
                                child: Text('Batalkan'),
                              ),
                            ],
                          )
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
