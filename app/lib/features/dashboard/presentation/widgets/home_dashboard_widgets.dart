part of '../pages/home_page.dart';

const _cashierPaymentMethodOrder = ['CASH', 'QRIS', 'TRANSFER', 'EDC'];

class _SummaryMetricsRow extends StatelessWidget {
  const _SummaryMetricsRow({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

class _MetricCardSkeleton extends StatelessWidget {
  const _MetricCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20, child: LinearProgressIndicator()),
            SizedBox(height: AppSpacing.sm),
            SizedBox(height: 28, child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

class _StaffTodayOrdersSummaryCard extends ConsumerWidget {
  const _StaffTodayOrdersSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(staffTodayOrdersProvider);
    return async.when(
      loading: () => const _SummaryMetricsRow(
        cards: [_MetricCardSkeleton(), _MetricCardSkeleton()],
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text('Gagal memuat ringkasan: $e'),
        ),
      ),
      data: (orders) {
        final total = orders.fold<double>(0, (sum, o) => sum + o.total);
        return _SummaryMetricsRow(
          cards: [
            _MetricCard(
              title: 'Order',
              value: '${orders.length}',
              icon: Icons.receipt_long_outlined,
            ),
            _MetricCard(
              title: 'Total nilai',
              value: formatRupiah(total),
              icon: Icons.payments_outlined,
            ),
          ],
        );
      },
    );
  }
}

class _StaffTodayOrdersListCard extends ConsumerWidget {
  const _StaffTodayOrdersListCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(staffTodayOrdersProvider);
    return async.when(
      loading: () => const Card(
        child: AsyncLoadingView(message: 'Memuat daftar order…'),
      ),
      error: (e, _) => Card(
        child: AsyncErrorView.fromError(
          e,
          onRetry: () => ref.invalidate(staffTodayOrdersProvider),
        ),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return const Card(
            child: EmptyStateView(
              title: 'Belum ada order hari ini',
              subtitle: 'Order yang Anda buat akan muncul di sini',
              icon: Icons.receipt_long_outlined,
            ),
          );
        }
        return Card(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(staffTodayOrdersProvider);
              await ref.read(staffTodayOrdersProvider.future);
            },
            child: ListView.separated(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: orders.length,
              separatorBuilder: (_, unused) => const Divider(height: 1),
              itemBuilder: (context, index) => _HomeOrderListTile(
                order: orders[index],
                leadingIcon: Icons.receipt_long_outlined,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CashierTodayPaymentSummaryCard extends ConsumerWidget {
  const _CashierTodayPaymentSummaryCard();

  Map<String, double> _totalsByMethod(List<PaymentSummary> payments) {
    final map = <String, double>{};
    for (final p in payments) {
      final key = p.paymentMethod.toUpperCase();
      map[key] = (map[key] ?? 0) + p.amount;
    }
    return map;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cashierTodayPaymentsProvider);
    return async.when(
      loading: () => const _SummaryMetricsRow(
        cards: [_MetricCardSkeleton(), _MetricCardSkeleton()],
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text('Gagal memuat ringkasan: $e'),
        ),
      ),
      data: (payments) {
        final grandTotal =
            payments.fold<double>(0, (sum, p) => sum + p.amount);
        final byMethod = _totalsByMethod(payments);
        final methods = [
          ..._cashierPaymentMethodOrder.where(byMethod.containsKey),
          ...byMethod.keys.where((k) => !_cashierPaymentMethodOrder.contains(k)),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryMetricsRow(
              cards: [
                _MetricCard(
                  title: 'Transaksi',
                  value: '${payments.length}',
                  icon: Icons.payments_outlined,
                ),
                _MetricCard(
                  title: 'Total',
                  value: formatRupiah(grandTotal),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
            ),
            if (methods.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Per metode bayar',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (var i = 0; i < methods.length; i++) ...[
                        if (i > 0) const Divider(height: AppSpacing.lg),
                        _PaymentCategoryRow(
                          label: paymentMethodLabel(methods[i]),
                          amount: byMethod[methods[i]]!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PaymentCategoryRow extends StatelessWidget {
  const _PaymentCategoryRow({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(
          formatRupiah(amount),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _PharmacistTodayReviewsSummaryCard extends ConsumerWidget {
  const _PharmacistTodayReviewsSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pharmacistTodayReviewsProvider);
    return async.when(
      loading: () => const _SummaryMetricsRow(
        cards: [_MetricCardSkeleton(), _MetricCardSkeleton()],
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text('Gagal memuat ringkasan: $e'),
        ),
      ),
      data: (orders) {
        final total = orders.fold<double>(0, (sum, o) => sum + o.total);
        return _SummaryMetricsRow(
          cards: [
            _MetricCard(
              title: 'Telaah',
              value: '${orders.length}',
              icon: Icons.fact_check_outlined,
            ),
            _MetricCard(
              title: 'Total nilai',
              value: formatRupiah(total),
              icon: Icons.payments_outlined,
            ),
          ],
        );
      },
    );
  }
}

class _PharmacistPendingReviewsListCard extends ConsumerWidget {
  const _PharmacistPendingReviewsListCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingPharmacyOrdersHomeProvider);
    return async.when(
      loading: () => const Card(
        child: AsyncLoadingView(message: 'Memuat antrian telaah…'),
      ),
      error: (e, _) => Card(
        child: AsyncErrorView.fromError(
          e,
          onRetry: () => ref.invalidate(pendingPharmacyOrdersHomeProvider),
        ),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return const Card(
            child: EmptyStateView(
              title: 'Tidak ada order menunggu telaah',
              icon: Icons.medical_services_outlined,
            ),
          );
        }
        return Card(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(pendingPharmacyOrdersHomeProvider);
              await ref.read(pendingPharmacyOrdersHomeProvider.future);
            },
            child: ListView.separated(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: orders.length,
              separatorBuilder: (_, unused) => const Divider(height: 1),
              itemBuilder: (context, index) => _HomeOrderListTile(
                order: orders[index],
                leadingIcon: Icons.medical_services_outlined,
                onTap: () => context.push('/orders/${orders[index].id}'),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeOrderListTile extends StatelessWidget {
  const _HomeOrderListTile({
    required this.order,
    required this.leadingIcon,
    this.onTap,
  });

  final OrderSummary order;
  final IconData leadingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');
    final time = order.createdAt != null
        ? timeFmt.format(order.createdAt!.toLocal())
        : null;

    return ListTile(
      onTap: onTap ?? () => context.push('/orders/${order.id}'),
      leading: CircleAvatar(
        backgroundColor: orderStatusColor(order.status).withValues(alpha: 0.12),
        child: Icon(
          leadingIcon,
          color: orderStatusColor(order.status),
          size: 22,
        ),
      ),
      title: Text(
        order.orderNumber,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  order.customerName ?? 'Walk-in',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: orderStatusColor(order.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  orderStatusLabel(order.status),
                  style: TextStyle(
                    fontSize: 10,
                    color: orderStatusColor(order.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (time != null)
            Text(
              time,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
      trailing: Text(
        formatRupiah(order.total),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CashierWaitingOrdersCard extends ConsumerWidget {
  const _CashierWaitingOrdersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(waitingOrdersProvider);
    final timeFmt = DateFormat('HH:mm');

    return async.when(
      loading: () => const Card(
        child: AsyncLoadingView(message: 'Memuat order…'),
      ),
      error: (e, _) => Card(
        child: AsyncErrorView.fromError(
          e,
          onRetry: () => ref.invalidate(waitingOrdersProvider),
        ),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return const Card(
            child: EmptyStateView(
              title: 'Tidak ada order menunggu pembayaran',
              icon: Icons.point_of_sale_outlined,
            ),
          );
        }

        return Card(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(waitingOrdersProvider);
              await ref.read(waitingOrdersProvider.future);
            },
            child: ListView.separated(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: orders.length,
              separatorBuilder: (_, unused) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final o = orders[index];
                return ListTile(
                  onTap: () => context.push('/cashier/orders/${o.id}'),
                  leading: CircleAvatar(
                    backgroundColor:
                        orderStatusColor(o.status).withValues(alpha: 0.12),
                    child: Icon(
                      Icons.point_of_sale_outlined,
                      color: orderStatusColor(o.status),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    o.orderNumber,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              o.customerName ?? 'Walk-in',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: orderStatusColor(o.status)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              orderStatusLabel(o.status),
                              style: TextStyle(
                                fontSize: 10,
                                color: orderStatusColor(o.status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (o.createdAt != null)
                        Text(
                          timeFmt.format(o.createdAt!.toLocal()),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  trailing: Text(
                    formatRupiah(o.total),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _OwnerSummaryCards extends ConsumerWidget {
  const _OwnerSummaryCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_dashboardProvider);
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Gagal load dashboard: $e'),
      data: (d) {
        final cards = [
          _MetricCard(
                title: 'Penjualan',
                value: formatRupiah(d.todaySales),
                icon: Icons.payments_outlined,
              ),
          _MetricCard(
                title: 'Order',
                value: '${d.todayOrders}',
                icon: Icons.receipt_long_outlined,
              ),
          _MetricCard(
            title: 'Stok rendah',
                value: '${d.lowStock}',
                icon: Icons.warning_amber_outlined,
              ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 520) {
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    cards[i],
                  ],
                ],
              );
            }
            return Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(child: cards[i]),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopMedicinesCard extends ConsumerWidget {
  const _TopMedicinesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_topMedicinesProvider);
    return Card(
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: LinearProgressIndicator(),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text('Gagal load top medicines: $e'),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('Belum ada data hari ini'),
            );
          }
          return Column(
            children: [
              for (final row in items.take(5))
                ListTile(
                  dense: true,
                  leading: AppIcon3D.list(
                    icon: Icons.medication_outlined,
                    accentKey: row.medicineName,
                  ),
                  title: Text(row.medicineName),
                  subtitle: Text('Qty: ${row.qty}${row.unit != null ? ' ${row.unit}' : ''}'),
                  trailing: Text(formatRupiah(row.subtotal)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LowStockCard extends ConsumerWidget {
  const _LowStockCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_lowStockProvider);
    return Card(
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: LinearProgressIndicator(),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text('Gagal load low stock: $e'),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('Aman — tidak ada stok menipis'),
            );
          }
          return Column(
            children: [
              for (final row in items.take(5))
                ListTile(
                  dense: true,
                  leading: AppIcon3D.list(
                    icon: Icons.warning_amber_outlined,
                    accentKey: row.medicineName,
                    accent: AppColors.danger,
                  ),
                  title: Text(row.medicineName),
                  subtitle: Text(
                    'Available: ${row.availableQuantity} · Min: ${row.minStock}',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

final _dashboardProvider = FutureProvider.autoDispose<DashboardSummary>((ref) async {
  return ref.watch(reportsRepositoryProvider).getDashboard();
});

final _topMedicinesProvider = FutureProvider.autoDispose<List<TopMedicineRow>>((ref) async {
  final now = DateTime.now();
  final iso = DateTime(now.year, now.month, now.day).toIso8601String();
  return ref.watch(reportsRepositoryProvider).topMedicines(
        dateFrom: iso,
        dateTo: iso,
        limit: 10,
        orderBy: 'qty',
      );
});

final _lowStockProvider = FutureProvider.autoDispose<List<LowStockRow>>((ref) async {
  return ref.watch(reportsRepositoryProvider).lowStock();
});

class _ProfileSummaryCard extends ConsumerWidget {
  const _ProfileSummaryCard({required this.user});

  final AuthUser user;

  String? _organizationLine() {
    if (user.isSuperAdmin) return 'Platform ApotikFlow';
    final parts = <String>[];
    final tenant = user.tenantName ?? user.tenantId;
    if (tenant != null && tenant.isNotEmpty) parts.add(tenant);
    if (user.branchName != null && user.branchName!.isNotEmpty) {
      parts.add(user.branchName!);
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgLine = _organizationLine();
    final activeRoleLabel = RoleLabels.labelForUser(user);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon3D.avatar(
              icon: user.isSuperAdmin
                  ? Icons.shield_outlined
                  : Icons.person_outline,
              accentKey: user.email,
              accent: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hai, ${user.name}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Peran aktif: $activeRoleLabel',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (user.canSwitchRole)
                        Text(
                          '${user.rolesAtBranch(user.branchId).length} peran',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                        ),
                      if (user.hasMultipleBranches)
                        Text(
                          '${user.branchIds.length} cabang',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                        ),
                    ],
                  ),
                  if (orgLine != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      orgLine,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (user.canSwitchBranch)
              IconButton(
                tooltip: 'Ganti cabang',
                icon: const Icon(Icons.store_mall_directory_outlined),
                onPressed: () async {
                  final branchId = await showBranchPickerDialog(
                    context,
                    user: user,
                  );
                  if (branchId == null || branchId == user.branchId) return;
                  final role = resolveRoleForBranch(user, branchId);
                  final ok = await ref.read(authProvider.notifier).switchSession(
                        role: role,
                        branchId: branchId,
                      );
                  if (!ok || !context.mounted) return;
                  ref.invalidate(waitingOrdersProvider);
                  context.go('/home');
                  final updated = ref.read(authProvider).user;
                  if (updated == null) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Cabang: ${updated.branchName ?? branchId}'
                        ' · Peran: ${RoleLabels.labelForUser(updated)}',
                      ),
                    ),
                  );
                },
              ),
            if (user.canSwitchRole)
              IconButton(
                tooltip: 'Ganti peran',
                icon: const Icon(Icons.swap_horiz),
                onPressed: () async {
                  final role = await showSessionRolePickerDialog(
                    context,
                    user: user,
                  );
                  if (role == null || role == user.role) return;
                  final ok =
                      await ref.read(authProvider.notifier).switchRole(role);
                  if (!ok || !context.mounted) return;
                  ref.invalidate(waitingOrdersProvider);
                  context.go('/home');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Peran aktif: ${RoleLabels.label(role, branchId: user.branchId)}',
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
