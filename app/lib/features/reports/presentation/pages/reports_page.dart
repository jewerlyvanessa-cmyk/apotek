import 'package:file_saver/file_saver.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../../shared/utils/currency_formatter.dart';
import '../../data/reports_repository.dart';
import '../../domain/entities/report_models.dart';
import '../../utils/owner_report_print.dart';
import '../../utils/report_file_export.dart';
import '../providers/report_date_filter.dart';
import '../widgets/report_date_filter_bar.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  bool _printing = false;

  Future<void> _handlePrint() async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      final filter = ref.read(reportDateFilterProvider);
      final config = ref.read(appConfigProvider);
      final results = await Future.wait([
        ref.read(reportsRepositoryProvider).getDashboard(
              dateFrom: filter.dateFromIso,
              dateTo: filter.dateToIso,
            ),
        ref.read(reportsRepositoryProvider).sales(
              dateFrom: filter.dateFromIso,
              dateTo: filter.dateToIso,
            ),
        ref.read(reportsRepositoryProvider).profitLoss(
              dateFrom: filter.dateFromIso,
              dateTo: filter.dateToIso,
            ),
      ]);
      await OwnerReportPrint.print(
        OwnerReportPrintData(
          appName: config.appName,
          periodLabel: filter.label(),
          dashboard: results[0] as DashboardSummary,
          sales: results[1] as SalesReport,
          profitLoss: results[2] as ProfitLossReport,
        ),
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
    return DefaultTabController(
      length: 5,
      child: AppScaffold(
        title: 'Laporan',
        actions: [
          Semantics(
            label: 'Cetak laporan owner',
            button: true,
            child: IconButton(
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
          ),
        ],
        body: Column(
          children: [
            const ReportDateFilterBar(),
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Ringkasan'),
                Tab(text: 'Penjualan'),
                Tab(text: 'Laba Rugi'),
                Tab(text: 'Top Obat'),
                Tab(text: 'Kadaluarsa'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _SummaryTab(),
                  _SalesTab(),
                  _ProfitLossTab(),
                  _TopTab(),
                  _ExpiredTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _dashboardProvider =
    FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final filter = ref.watch(reportDateFilterProvider);
  return ref.watch(reportsRepositoryProvider).getDashboard(
        dateFrom: filter.dateFromIso,
        dateTo: filter.dateToIso,
      );
});

final _topMedicinesProvider =
    FutureProvider.autoDispose<List<TopMedicineRow>>((ref) async {
  final filter = ref.watch(reportDateFilterProvider);
  return ref.watch(reportsRepositoryProvider).topMedicines(
        dateFrom: filter.dateFromIso,
        dateTo: filter.dateToIso,
        limit: 10,
        orderBy: 'qty',
      );
});

final _profitLossProvider =
    FutureProvider.autoDispose<ProfitLossReport>((ref) async {
  final filter = ref.watch(reportDateFilterProvider);
  return ref.watch(reportsRepositoryProvider).profitLoss(
        dateFrom: filter.dateFromIso,
        dateTo: filter.dateToIso,
      );
});

final _salesProvider = FutureProvider.autoDispose<SalesReport>((ref) async {
  final filter = ref.watch(reportDateFilterProvider);
  return ref.watch(reportsRepositoryProvider).sales(
        dateFrom: filter.dateFromIso,
        dateTo: filter.dateToIso,
      );
});

final _expiredProvider = FutureProvider.autoDispose<List<ExpiredRow>>((ref) async {
  return ref.watch(reportsRepositoryProvider).expired();
});

Future<void> _exportReport(
  WidgetRef ref,
  BuildContext context, {
  required String path,
  required String fileName,
  required MimeType mime,
}) async {
  final filter = ref.read(reportDateFilterProvider);
  try {
    final bytes = await ref.read(reportsRepositoryProvider).downloadReport(
          path,
          dateFrom: filter.dateFromIso,
          dateTo: filter.dateToIso,
        );
    await saveReportBytes(
      bytes: bytes,
      fileName: fileName,
      mimeType: mime,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$fileName berhasil diunduh'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export gagal: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportDateFilterProvider);
    final async = ref.watch(_dashboardProvider);
    final salesLabel = filter.isSingleDay ? 'Penjualan' : 'Total penjualan';
    final ordersLabel = filter.isSingleDay ? 'Order' : 'Total order';

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (d) {
          return ListView(
            children: [
              Text(
                'Periode: ${filter.label()}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: salesLabel,
                      value: formatRupiah(d.todaySales),
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _MetricCard(
                      title: ordersLabel,
                      value: '${d.todayOrders}',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _MetricCard(
                title: 'Stok rendah (saat ini)',
                value: '${d.lowStock}',
                icon: Icons.warning_amber_outlined,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SalesTab extends ConsumerWidget {
  const _SalesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportDateFilterProvider);
    final async = ref.watch(_salesProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (r) {
          final points = _dailyTotals(r.orders);
          final maxY = points.isEmpty
              ? 1.0
              : points.map((e) => e.total).reduce((a, b) => a > b ? a : b);

          return ListView(
            children: [
              Text(
                'Periode: ${filter.label()}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _exportReport(
                      ref,
                      context,
                      path: '/reports/sales/export.xlsx',
                      fileName: 'sales-report.xlsx',
                      mime: reportMimeXlsx(),
                    ),
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Excel'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _exportReport(
                      ref,
                      context,
                      path: '/reports/sales/export.pdf',
                      fileName: 'sales-report.pdf',
                      mime: reportMimePdf(),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _MetricCard(
                title: 'Total periode',
                value: formatRupiah(r.totals.total),
                icon: Icons.insights_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SizedBox(
                    height: 220,
                    child: points.isEmpty
                        ? const Center(child: Text('Belum ada data'))
                        : LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: maxY * 1.2,
                              gridData: const FlGridData(show: true),
                              titlesData: FlTitlesData(
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: points.length > 7 ? 2 : 1,
                                    getTitlesWidget: (value, meta) {
                                      final i = value.toInt();
                                      if (i < 0 || i >= points.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          points[i].label,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: [
                                    for (var i = 0; i < points.length; i++)
                                      FlSpot(i.toDouble(), points[i].total),
                                  ],
                                  isCurved: true,
                                  barWidth: 3,
                                  color: AppColors.primary,
                                  dotData: const FlDotData(show: false),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Order terbaru',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Column(
                  children: [
                    if (r.orders.isEmpty)
                      const ListTile(title: Text('Tidak ada order'))
                    else
                      for (final o in r.orders.reversed.take(10))
                        ListTile(
                          dense: true,
                          onTap: o.id.isNotEmpty
                              ? () => context.push('/orders/${o.id}')
                              : null,
                          leading: AppIcon3D.list(
                            icon: Icons.receipt_long_outlined,
                            accentKey: o.orderNumber,
                          ),
                          title: Text(o.orderNumber),
                          subtitle: Text(
                            o.paidAt != null
                                ? DateFormat('dd MMM yyyy, HH:mm')
                                    .format(o.paidAt!.toLocal())
                                : '-',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(formatRupiah(o.total)),
                              if (o.id.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, size: 20),
                              ],
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfitLossTab extends ConsumerWidget {
  const _ProfitLossTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportDateFilterProvider);
    final async = ref.watch(_profitLossProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (r) {
          if (r.items.isEmpty) {
            return Center(
              child: Text('Belum ada data untuk ${filter.label()}'),
            );
          }
          return ListView(
            children: [
              Text(
                'Periode: ${filter.label()}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _exportReport(
                      ref,
                      context,
                      path: '/reports/profit-loss/export.xlsx',
                      fileName: 'profit-loss-report.xlsx',
                      mime: reportMimeXlsx(),
                    ),
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Excel'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'Pendapatan',
                      value: formatRupiah(r.totals.revenue),
                      icon: Icons.trending_up,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _MetricCard(
                      title: 'Laba kotor',
                      value: formatRupiah(r.totals.grossProfit),
                      icon: Icons.savings_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'HPP: ${formatRupiah(r.totals.cost)} · Margin ${r.totals.marginPercent.toStringAsFixed(1)}%',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              ...r.items.take(20).map(
                    (row) => Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(row.medicineName),
                        subtitle: Text(
                          '${row.qty}${row.unit != null ? ' ${row.unit}' : ''} · HPP ${formatRupiah(row.cost)}',
                        ),
                        trailing: Text(
                          formatRupiah(row.grossProfit),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _TopTab extends ConsumerWidget {
  const _TopTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportDateFilterProvider);
    final async = ref.watch(_topMedicinesProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text('Belum ada data untuk ${filter.label()}'),
            );
          }

          final top = items.take(7).toList();
          final maxY = top.map((e) => e.qty.toDouble()).reduce((a, b) => a > b ? a : b);

          return ListView(
            children: [
              Text(
                'Periode: ${filter.label()}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SizedBox(
                    height: 240,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY * 1.2,
                        gridData: const FlGridData(show: true),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= top.length) {
                                  return const SizedBox.shrink();
                                }
                                final name = top[i].medicineName;
                                final short =
                                    name.length > 8 ? '${name.substring(0, 8)}…' : name;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(short, style: const TextStyle(fontSize: 10)),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          for (var i = 0; i < top.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: top[i].qty.toDouble(),
                                  color: AppColors.primary,
                                  width: 14,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Column(
                  children: [
                    for (final row in items.take(10))
                      ListTile(
                        dense: true,
                        leading: AppIcon3D.list(
                          icon: Icons.medication_outlined,
                          accentKey: row.medicineName,
                        ),
                        title: Text(row.medicineName),
                        subtitle: Text(
                          'Qty: ${row.qty}${row.unit != null ? ' ${row.unit}' : ''}',
                        ),
                        trailing: Text(formatRupiah(row.subtotal)),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExpiredTab extends ConsumerWidget {
  const _ExpiredTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_expiredProvider);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Batch kadaluarsa (tidak terpengaruh filter tanggal)',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat: $e')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('Tidak ada batch kadaluarsa'));
                }
                return Card(
                  child: ListView(
                    children: [
                      for (final row in items.take(50))
                        ListTile(
                          dense: true,
                          leading: AppIcon3D.list(
                            icon: Icons.event_busy,
                            accentKey: row.medicineName,
                            accent: AppColors.danger,
                          ),
                          title: Text(row.medicineName),
                          subtitle: Text(
                            'Batch: ${row.batchNumber} · Exp: ${row.expiredDate}',
                          ),
                          trailing: Text('Qty ${row.quantity}'),
                        ),
                    ],
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
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyPoint {
  const _DailyPoint(this.day, this.total);
  final DateTime day;
  final double total;
  String get label => DateFormat('dd/MM').format(day);
}

List<_DailyPoint> _dailyTotals(List<SalesOrderRow> orders) {
  if (orders.isEmpty) return const [];
  final byDay = <DateTime, double>{};
  for (final o in orders) {
    final dt = o.paidAt;
    if (dt == null) continue;
    final day = DateTime(dt.year, dt.month, dt.day);
    byDay[day] = (byDay[day] ?? 0) + o.total;
  }
  final keys = byDay.keys.toList()..sort();
  return keys.map((k) => _DailyPoint(k, byDay[k] ?? 0)).toList();
}
