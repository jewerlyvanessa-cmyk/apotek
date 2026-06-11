import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/async_error_view.dart';
import '../../../../shared/widgets/async_loading_view.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../../../shared/widgets/pagination_bar.dart';
import '../../../../core/network/paginated_result.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/stock_repository.dart';
import '../providers/stock_provider.dart';
import '../../domain/entities/stock_movement.dart';

final _movementsProvider = FutureProvider.autoDispose
    .family<PaginatedResult<StockMovementRow>, _MovementQuery>((ref, q) async {
  final user = ref.watch(authProvider).user;
  final raw = q.branchId ?? ref.watch(effectiveBranchIdProvider);
  final branchId =
      user == null ? raw : resolveStockBranchId(user, raw);
  return ref.watch(stockRepositoryProvider).getMovements(
        branchId: branchId,
        search: q.search,
        page: q.page,
      );
});

class StockMovementsPage extends ConsumerStatefulWidget {
  const StockMovementsPage({super.key, this.branchId});

  final String? branchId;

  @override
  ConsumerState<StockMovementsPage> createState() => _StockMovementsPageState();
}

class _StockMovementsPageState extends ConsumerState<StockMovementsPage> {
  final _searchController = TextEditingController();
  String _search = '';
  int _page = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _MovementQuery(
      branchId: widget.branchId,
      search: _search,
      page: _page,
    );
    final async = ref.watch(_movementsProvider(q));

    return AppScaffold(
      title: 'Movement History',
      actions: [
        Semantics(
          label: 'Muat ulang riwayat mutasi',
          button: true,
          child: IconButton(
            tooltip: 'Muat ulang',
            onPressed: () => ref.invalidate(_movementsProvider(q)),
            icon: const Icon(Icons.refresh),
          ),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: Semantics(
              label: 'Cari riwayat mutasi stok',
              textField: true,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Cari notes / movement type...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onSubmitted: (v) => setState(() {
                  _search = v.trim();
                  _page = 1;
                }),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const AsyncLoadingView(),
              error: (e, _) => AsyncErrorView.fromError(
                e,
                onRetry: () => ref.invalidate(_movementsProvider(q)),
              ),
              data: (result) {
                if (result.items.isEmpty) {
                  return const EmptyStateView(
                    title: 'Belum ada movement',
                    subtitle: 'Riwayat mutasi stok akan muncul di sini.',
                    icon: Icons.history,
                  );
                }
                final fmt = DateFormat('dd/MM/yyyy HH:mm');
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: result.items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == result.items.length) {
                      return PaginationBar(
                        meta: result.meta,
                        onPageChanged: (p) => setState(() => _page = p),
                      );
                    }
                    final m = result.items[index];
                    final qtyColor =
                        m.quantity >= 0 ? AppColors.success : AppColors.danger;
                    return Semantics(
                      label:
                          '${m.movementType}, jumlah ${m.quantity >= 0 ? '+' : ''}${m.quantity}',
                      child: Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(
                          m.movementType,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          [
                            if (m.notes != null && m.notes!.isNotEmpty) m.notes!,
                            if (m.createdAt != null)
                              fmt.format(m.createdAt!.toLocal()),
                          ].join('\n'),
                        ),
                        trailing: Text(
                          '${m.quantity >= 0 ? '+' : ''}${m.quantity}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: qtyColor,
                          ),
                        ),
                      ),
                    ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementQuery {
  const _MovementQuery({
    required this.branchId,
    required this.search,
    required this.page,
  });

  final String? branchId;
  final String search;
  final int page;

  @override
  bool operator ==(Object other) =>
      other is _MovementQuery &&
      other.branchId == branchId &&
      other.search == search &&
      other.page == page;

  @override
  int get hashCode => Object.hash(branchId, search, page);
}
