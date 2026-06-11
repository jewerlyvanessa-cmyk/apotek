import 'package:intl/intl.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../order/domain/entities/order.dart';
import '../../order/presentation/utils/order_status_ui.dart';
import 'report_print_platform.dart';

class BranchReportPrintData {
  const BranchReportPrintData({
    required this.appName,
    required this.branchName,
    required this.periodLabel,
    required this.totalOrders,
    required this.paidCount,
    required this.pendingCount,
    required this.waitingCount,
    required this.revenue,
    required this.orders,
  });

  final String appName;
  final String branchName;
  final String periodLabel;
  final int totalOrders;
  final int paidCount;
  final int pendingCount;
  final int waitingCount;
  final double revenue;
  final List<OrderSummary> orders;
}

abstract final class BranchReportPrint {
  static Future<void> print(BranchReportPrintData data) async {
    await openAndPrintHtml(_buildHtml(data));
  }

  static String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static String _buildHtml(BranchReportPrintData data) {
    final printedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final rows = data.orders
        .map(
          (o) => '''
        <tr>
          <td>${_escape(o.orderNumber)}</td>
          <td>${_escape(orderStatusLabel(o.status))}</td>
          <td style="text-align:right">${_escape(formatRupiah(o.total))}</td>
        </tr>''',
        )
        .join();

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Laporan Cabang</title>
  <style>
    body { font-family: sans-serif; font-size: 12px; margin: 16px; }
    h1 { font-size: 16px; margin: 0 0 4px; }
    .meta { color: #555; margin-bottom: 12px; }
    .summary { margin-bottom: 12px; }
    .summary div { display: flex; justify-content: space-between; margin: 2px 0; }
    table { width: 100%; border-collapse: collapse; }
    th, td { border-bottom: 1px solid #ddd; padding: 4px 6px; text-align: left; }
    th { background: #f5f5f5; }
  </style>
</head>
<body>
  <h1>${_escape(data.appName)}</h1>
  <div class="meta">Laporan Cabang · ${_escape(data.branchName)}</div>
  <div class="meta">Periode: ${_escape(data.periodLabel)}</div>
  <div class="summary">
    <div><span>Total order</span><strong>${data.totalOrders}</strong></div>
    <div><span>Lunas</span><strong>${data.paidCount}</strong></div>
    <div><span>Omzet lunas</span><strong>${_escape(formatRupiah(data.revenue))}</strong></div>
    <div><span>Menunggu telaah</span><strong>${data.pendingCount}</strong></div>
    <div><span>Menunggu bayar</span><strong>${data.waitingCount}</strong></div>
  </div>
  <table>
    <thead>
      <tr><th>Order</th><th>Status</th><th>Total</th></tr>
    </thead>
    <tbody>$rows</tbody>
  </table>
  <p class="meta">Dicetak $printedAt</p>
</body>
</html>''';
  }
}
