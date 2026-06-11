import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/printing/printer_providers.dart';
import '../../../../core/printing/thermal_printer_settings.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../../shared/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../cashier/data/cash_entry_repository.dart';
import '../../../payment/data/payment_repository.dart';
import '../../../cashier/domain/entities/cash_entry.dart';
import '../../../payment/domain/entities/payment_summary.dart'
    show PaymentSummary, paymentMethodLabel;
import '../../../../shared/widgets/async_error_view.dart';
import '../../../../shared/widgets/async_loading_view.dart';
import '../../data/reports_repository.dart';
import '../../domain/entities/report_models.dart';
import '../../utils/cashier_report_print.dart';
import '../providers/report_date_filter.dart';
import '../widgets/report_date_filter_bar.dart';
import '../widgets/report_metric_card.dart';

final _cashierBranchDashboardProvider =
    FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final user = ref.watch(authProvider).user;
  final branchId = user?.branchId;
  if (branchId == null) throw Exception('Akun kasir tidak terikat cabang');
  final filter = ref.watch(reportDateFilterProvider);
  return ref.watch(reportsRepositoryProvider).getDashboard(
        dateFrom: filter.dateFromIso,
        dateTo: filter.dateToIso,
        branchId: branchId,
      );
});

final _cashierBranchSalesProvider =
    FutureProvider.autoDispose<SalesReport>((ref) async {
  final user = ref.watch(authProvider).user;
  final branchId = user?.branchId;
  if (branchId == null) throw Exception('Akun kasir tidak terikat cabang');
  final filter = ref.watch(reportDateFilterProvider);
  return ref.watch(reportsRepositoryProvider).sales(
        dateFrom: filter.dateFromIso,
        dateTo: filter.dateToIso,
        branchId: branchId,
      );
});

/// `null` = semua metode pembayaran.
final cashierReportPaymentMethodFilterProvider =
    StateProvider<String?>((ref) => null);

const _cashierReportPaymentMethods = [
  'CASH',
  'QRIS',
  'TRANSFER',
  'EDC',
];

Future<List<PaymentSummary>> _fetchBranchPayments(
  Ref ref, {
  String? paymentMethod,
  int limit = 100,
}) async {
  final user = ref.watch(authProvider).user;
  final branchId = user?.branchId;
  if (branchId == null) throw Exception('Akun kasir tidak terikat cabang');
  final filter = ref.watch(reportDateFilterProvider);
  final result = await ref.watch(paymentRepositoryProvider).getPayments(
        branchId: branchId,
        dateFrom: filter.dateFromIso,
        dateTo: filter.dateToIso,
        paymentMethod: paymentMethod,
        limit: limit,
      );
  return result.items;
}

/// Semua pembayaran periode (untuk ringkasan per metode & cetak).
final _cashierBranchPaymentsAllProvider =
    FutureProvider.autoDispose<List<PaymentSummary>>((ref) async {
  return _fetchBranchPayments(ref);
});

/// Daftar pembayaran — bisa difilter metode.
final _cashierBranchPaymentsProvider =
    FutureProvider.autoDispose<List<PaymentSummary>>((ref) async {
  final paymentMethod = ref.watch(cashierReportPaymentMethodFilterProvider);
  return _fetchBranchPayments(ref, paymentMethod: paymentMethod);
});

class CashierBranchReportPage extends ConsumerStatefulWidget {
  const CashierBranchReportPage({super.key});

  @override
  ConsumerState<CashierBranchReportPage> createState() =>
      _CashierBranchReportPageState();
}

class _CashierBranchReportPageState extends ConsumerState<CashierBranchReportPage> {
  bool _printing = false;

  Future<CashierReportPrintData?> _loadPrintData() async {
    final user = ref.read(authProvider).user;
    if (user?.branchId == null) return null;

    final filter = ref.read(reportDateFilterProvider);
    final config = ref.read(appConfigProvider);
    final branchId = user!.branchId!;
    final results = await Future.wait([
      ref.read(_cashierBranchDashboardProvider.future),
      ref.read(_cashierBranchSalesProvider.future),
      ref.read(_cashierBranchPaymentsAllProvider.future),
      ref.read(cashEntryRepositoryProvider).summary(
            branchId: branchId,
            dateFrom: filter.dateFromIso,
            dateTo: filter.dateToIso,
          ),
      ref.read(cashEntryRepositoryProvider).list(
            branchId: branchId,
            dateFrom: filter.dateFromIso,
            dateTo: filter.dateToIso,
            limit: 100,
          ),
    ]);

    return CashierReportPrintData(
      appName: config.appName,
      branchName: user.branchName ?? branchId,
      periodLabel: filter.label(),
      cashierName: user.name,
      dashboard: results[0] as DashboardSummary,
      sales: results[1] as SalesReport,
      payments: results[2] as List<PaymentSummary>,
      cashSummary: results[3] as CashLedgerSummary,
      cashEntries: results[4] as List<CashEntry>,
    );
  }

  Future<String?> _pickPrintMode() async {
    if (kIsWeb) return 'pdf';
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: const Text('Cetak'),
              subtitle: const Text('Buka di browser lalu dialog cetak'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Cetak thermal'),
              subtitle: const Text('Printer struk jaringan (ESC/POS)'),
              onTap: () => Navigator.pop(ctx, 'thermal'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePrint() async {
    if (_printing) return;

    final mode = await _pickPrintMode();
    if (mode == null || !mounted) return;

    setState(() => _printing = true);
    try {
      final data = await _loadPrintData();
      if (data == null) {
        throw Exception('Akun tidak terikat cabang');
      }

      if (mode == 'thermal') {
        final prefs = ref.read(prefsProvider);
        final settings = await ThermalPrinterSettings.load(prefs);
        await ref.read(thermalPrinterServiceProvider).printCashierReport(
              host: settings.host,
              port: settings.port,
              data: data,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Laporan terkirim ke printer thermal'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        await CashierReportPrint.print(data);
      }
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
        title: 'Laporan Kasir',
        body: Center(
          child: Text('Akun tidak terikat cabang. Hubungi admin.'),
        ),
      );
    }

    final filter = ref.watch(reportDateFilterProvider);
    final dashboardAsync = ref.watch(_cashierBranchDashboardProvider);
    final salesAsync = ref.watch(_cashierBranchSalesProvider);
    final paymentsAllAsync = ref.watch(_cashierBranchPaymentsAllProvider);
    final paymentsAsync = ref.watch(_cashierBranchPaymentsProvider);
    final timeFmt = DateFormat('dd MMM yyyy, HH:mm');

    return AppScaffold(
      title: 'Laporan Kasir',
      actions: [
        IconButton(
          tooltip: 'Cetak laporan',
          onPressed: _printing ? null : _handlePrint,
          icon: _printing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.print_outlined),
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
          const _PaymentMethodFilterCard(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_cashierBranchDashboardProvider);
                ref.invalidate(_cashierBranchSalesProvider);
                ref.invalidate(_cashierBranchPaymentsAllProvider);
                ref.invalidate(_cashierBranchPaymentsProvider);
                await Future.wait([
                  ref.read(_cashierBranchDashboardProvider.future),
                  ref.read(_cashierBranchSalesProvider.future),
                  ref.read(_cashierBranchPaymentsAllProvider.future),
                  ref.read(_cashierBranchPaymentsProvider.future),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(
                    'Periode: ${filter.label()}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  dashboardAsync.when(
                    loading: () => const AsyncLoadingView(),
                    error: (e, _) => AsyncErrorView.fromError(e),
                    data: (d) => Row(
                      children: [
                        Expanded(
                          child: ReportMetricCard(
                            title: 'Pembayaran',
                            value: formatRupiah(d.todaySales),
                            icon: Icons.payments_outlined,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ReportMetricCard(
                            title: 'Order lunas',
                            value: '${d.todayOrders}',
                            icon: Icons.receipt_long_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  salesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => Text('Penjualan: $e'),
                    data: (s) => ReportMetricCard(
                      title: 'Total penjualan (order)',
                      value: formatRupiah(s.totals.total),
                      icon: Icons.insights_outlined,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  paymentsAllAsync.when(
                    loading: () => const Card(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (e, _) => Card(
                      child: ListTile(title: Text('Ringkasan metode: $e')),
                    ),
                    data: (payments) => _PaymentMethodTotalsCard(
                      payments: payments,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Builder(
                    builder: (context) {
                      final methodFilter =
                          ref.watch(cashierReportPaymentMethodFilterProvider);
                      final methodLabel = methodFilter == null
                          ? 'Semua metode'
                          : paymentMethodLabel(methodFilter);
                      return Text(
                        'Daftar pembayaran cabang · $methodLabel',
                        style: Theme.of(context).textTheme.titleMedium,
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  paymentsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                    data: (payments) {
                      if (payments.isEmpty) {
                        final methodFilter =
                            ref.watch(cashierReportPaymentMethodFilterProvider);
                        final emptyHint = methodFilter == null
                            ? 'Tidak ada pembayaran pada periode ini'
                            : 'Tidak ada pembayaran ${paymentMethodLabel(methodFilter)} pada periode ini';
                        return Card(
                          child: ListTile(
                            title: Text(emptyHint),
                          ),
                        );
                      }
                      final total = payments.fold<double>(
                        0,
                        (sum, p) => sum + p.amount,
                      );
                      return Card(
                        child: Column(
                          children: [
                            ListTile(
                              dense: true,
                              title: Text(
                                '${payments.length} transaksi · ${formatRupiah(total)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            for (final p in payments)
                              ListTile(
                                onTap: () => context.push('/payments/${p.id}'),
                                leading: AppIcon3D.list(
                                  icon: Icons.payments_outlined,
                                  accentKey: p.orderNumber,
                                  accent: AppColors.success,
                                ),
                                title: Text(
                                  p.orderNumber,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${p.customerName ?? 'Walk-in'} · ${paymentMethodLabel(p.paymentMethod)}'
                                  '${p.paidAt != null ? '\n${timeFmt.format(p.paidAt!.toLocal())}' : ''}',
                                ),
                                trailing: Text(
                                  formatRupiah(p.amount),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodTotalsCard extends ConsumerWidget {
  const _PaymentMethodTotalsCard({required this.payments});

  final List<PaymentSummary> payments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(cashierReportPaymentMethodFilterProvider);
    final byMethod = CashierReportPrint.totalsByMethod(payments);
    final methods = [
      ..._cashierReportPaymentMethods.where(byMethod.containsKey),
      ...byMethod.keys.where((k) => !_cashierReportPaymentMethods.contains(k)),
    ];
    final grandTotal = payments.fold<double>(0, (sum, p) => sum + p.amount);

    if (payments.isEmpty) {
      return const Card(
        child: ListTile(
          title: Text('Belum ada pembayaran pada periode ini'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart_outline, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Total per metode pembayaran',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${payments.length} transaksi · ${formatRupiah(grandTotal)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Divider(height: AppSpacing.lg),
            for (var i = 0; i < methods.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _PaymentMethodTotalRow(
                label: paymentMethodLabel(methods[i]),
                icon: _paymentMethodIcon(methods[i]),
                amount: byMethod[methods[i]]!,
                count: payments
                    .where((p) => p.paymentMethod.toUpperCase() == methods[i])
                    .length,
                highlighted: selected == methods[i],
                onTap: () {
                  ref.read(cashierReportPaymentMethodFilterProvider.notifier).state =
                      selected == methods[i] ? null : methods[i];
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodTotalRow extends StatelessWidget {
  const _PaymentMethodTotalRow({
    required this.label,
    required this.icon,
    required this.amount,
    required this.count,
    required this.highlighted,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final double amount;
  final int count;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted
          ? AppColors.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: highlighted ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight:
                            highlighted ? FontWeight.w700 : FontWeight.w600,
                        color: highlighted ? AppColors.primary : null,
                      ),
                    ),
                    Text(
                      '$count transaksi',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatRupiah(amount),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: highlighted ? AppColors.primary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _paymentMethodIcon(String? method) {
  switch (method?.toUpperCase()) {
    case 'CASH':
      return Icons.payments_outlined;
    case 'QRIS':
      return Icons.qr_code_2_outlined;
    case 'TRANSFER':
      return Icons.account_balance_outlined;
    case 'EDC':
      return Icons.credit_card_outlined;
    default:
      return Icons.filter_list_outlined;
  }
}

class _PaymentMethodFilterCard extends ConsumerWidget {
  const _PaymentMethodFilterCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(cashierReportPaymentMethodFilterProvider);
    final options = <String?>[null, ..._cashierReportPaymentMethods];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    _paymentMethodIcon(selected),
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Metode pembayaran',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final method in options)
                    _PaymentMethodOptionChip(
                      label: method == null
                          ? 'Semua'
                          : paymentMethodLabel(method),
                      icon: _paymentMethodIcon(method),
                      selected: selected == method,
                      onTap: () {
                        ref
                            .read(cashierReportPaymentMethodFilterProvider.notifier)
                            .state = method;
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodOptionChip extends StatelessWidget {
  const _PaymentMethodOptionChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.textSecondary.withValues(alpha: 0.25),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
