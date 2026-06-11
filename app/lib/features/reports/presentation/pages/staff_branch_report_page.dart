import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../../shared/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../order/data/order_repository.dart';
import '../../../order/domain/entities/order.dart';
import '../../../order/presentation/utils/order_status_ui.dart';
import '../../utils/branch_report_print_handler.dart';
import '../providers/report_date_filter.dart';
import '../widgets/report_date_filter_bar.dart';
import '../widgets/report_metric_card.dart';

final _staffBranchOrdersProvider =
    FutureProvider.autoDispose<List<OrderSummary>>((ref) async {
  final user = ref.watch(authProvider).user;
  final branchId = user?.branchId;
  if (branchId == null) throw Exception('Akun asisten tidak terikat cabang');
  final filter = ref.watch(reportDateFilterProvider);
  return ref.watch(orderRepositoryProvider).getOrders(
        branchId: branchId,
        dateFrom: filter.dateFromIso,
        dateTo: filter.dateToIso,
        limit: 100,
      );
});

class StaffBranchReportPage extends ConsumerStatefulWidget {
  const StaffBranchReportPage({super.key});

  @override
  ConsumerState<StaffBranchReportPage> createState() =>
      _StaffBranchReportPageState();
}

class _StaffBranchReportPageState extends ConsumerState<StaffBranchReportPage> {
  bool _printing = false;

  Future<void> _handlePrint(List<OrderSummary> orders, String branchLabel) async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      await printBranchReport(
        ref: ref,
        context: context,
        branchName: branchLabel,
        orders: orders,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laporan dikirim ke printer'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal cetak: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final branchLabel = user?.branchName ?? user?.branchId ?? 'Cabang';

    if (user?.branchId == null) {
      return const AppScaffold(
        title: 'Laporan Order',
        body: Center(
          child: Text('Akun tidak terikat cabang. Hubungi admin.'),
        ),
      );
    }

    final filter = ref.watch(reportDateFilterProvider);
    final ordersAsync = ref.watch(_staffBranchOrdersProvider);
    final timeFmt = DateFormat('dd MMM yyyy, HH:mm');

    return AppScaffold(
      title: 'Laporan Order',
      actions: [
        ordersAsync.maybeWhen(
          data: (orders) => IconButton(
            tooltip: 'Cetak laporan',
            onPressed:
                _printing || orders.isEmpty ? null : () => _handlePrint(orders, branchLabel),
            icon: _printing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
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
              'Cabang: $branchLabel',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const ReportDateFilterBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_staffBranchOrdersProvider);
                await ref.read(_staffBranchOrdersProvider.future);
              },
              child: ordersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (orders) {
                  final paid = orders.where((o) => o.status == 'PAID').length;
                  final waiting =
                      orders.where((o) => o.status == 'WAITING_PAYMENT').length;
                  final cancelled =
                      orders.where((o) => o.status == 'CANCELLED').length;
                  final paidTotal = orders
                      .where((o) => o.status == 'PAID')
                      .fold<double>(0, (s, o) => s + o.total);

                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      Text(
                        'Periode: ${filter.label()}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: ReportMetricCard(
                              title: 'Total order',
                              value: '${orders.length}',
                              icon: Icons.receipt_long_outlined,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: ReportMetricCard(
                              title: 'Lunas',
                              value: '$paid',
                              icon: Icons.check_circle_outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: ReportMetricCard(
                              title: 'Menunggu bayar',
                              value: '$waiting',
                              icon: Icons.hourglass_empty,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: ReportMetricCard(
                              title: 'Omzet lunas',
                              value: formatRupiah(paidTotal),
                              icon: Icons.payments_outlined,
                            ),
                          ),
                        ],
                      ),
                      if (cancelled > 0) ...[
                        const SizedBox(height: AppSpacing.md),
                        ReportMetricCard(
                          title: 'Dibatalkan',
                          value: '$cancelled',
                          icon: Icons.cancel_outlined,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Daftar order cabang',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (orders.isEmpty)
                        const Card(
                          child: ListTile(
                            title: Text('Tidak ada order pada periode ini'),
                          ),
                        )
                      else
                        Card(
                          child: Column(
                            children: [
                              for (final o in orders)
                                ListTile(
                                  onTap: () => context.push('/orders/${o.id}'),
                                  leading: AppIcon3D.list(
                                    icon: Icons.receipt_long_outlined,
                                    accentKey: o.orderNumber,
                                    accent: orderStatusColor(o.status),
                                  ),
                                  title: Text(
                                    o.orderNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${orderStatusLabel(o.status)} · ${o.customerName ?? 'Walk-in'}'
                                    '${o.createdAt != null ? '\n${timeFmt.format(o.createdAt!.toLocal())}' : ''}',
                                  ),
                                  trailing: Text(
                                    formatRupiah(o.total),
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
