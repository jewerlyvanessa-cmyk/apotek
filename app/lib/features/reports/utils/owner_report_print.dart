import 'package:intl/intl.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../domain/entities/report_models.dart';
import 'report_print_platform.dart';

class OwnerReportPrintData {
  const OwnerReportPrintData({
    required this.appName,
    required this.periodLabel,
    required this.dashboard,
    this.sales,
    this.profitLoss,
  });

  final String appName;
  final String periodLabel;
  final DashboardSummary dashboard;
  final SalesReport? sales;
  final ProfitLossReport? profitLoss;
}

abstract final class OwnerReportPrint {
  static Future<void> print(OwnerReportPrintData data) async {
    await openAndPrintHtml(_buildHtml(data));
  }

  static String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static String _buildHtml(OwnerReportPrintData data) {
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final d = data.dashboard;
    final salesBlock = data.sales == null
        ? ''
        : '''
    <h2>Penjualan</h2>
    <div class="summary">
      <div><span>Total penjualan</span><strong>${_escape(formatRupiah(data.sales!.totals.total))}</strong></div>
      <div><span>Jumlah order</span><strong>${data.sales!.totals.orders}</strong></div>
    </div>''';

    final pl = data.profitLoss;
    final plBlock = pl == null
        ? ''
        : '''
    <h2>Laba rugi</h2>
    <div class="summary">
      <div><span>Pendapatan</span><strong>${_escape(formatRupiah(pl.totals.revenue))}</strong></div>
      <div><span>HPP</span><strong>${_escape(formatRupiah(pl.totals.cost))}</strong></div>
      <div><span>Laba kotor</span><strong>${_escape(formatRupiah(pl.totals.grossProfit))}</strong></div>
      <div><span>Margin</span><strong>${pl.totals.marginPercent.toStringAsFixed(1)}%</strong></div>
    </div>''';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Laporan Owner</title>
  <style>
    body { font-family: sans-serif; font-size: 12px; margin: 16px; }
    h1 { font-size: 16px; margin: 0 0 4px; }
    h2 { font-size: 14px; margin: 16px 0 8px; }
    .meta { color: #555; margin-bottom: 12px; }
    .summary div { display: flex; justify-content: space-between; margin: 4px 0; }
  </style>
</head>
<body>
  <h1>${_escape(data.appName)}</h1>
  <div class="meta">Laporan Owner · ${_escape(data.periodLabel)}</div>
  <h2>Ringkasan</h2>
  <div class="summary">
    <div><span>Penjualan</span><strong>${_escape(formatRupiah(d.todaySales))}</strong></div>
    <div><span>Order</span><strong>${d.todayOrders}</strong></div>
    <div><span>Stok rendah</span><strong>${d.lowStock}</strong></div>
  </div>
  $salesBlock
  $plBlock
  <p class="meta">Dicetak $printedAt</p>
</body>
</html>''';
  }
}
