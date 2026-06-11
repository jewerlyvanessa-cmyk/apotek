import 'package:intl/intl.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../cashier/domain/entities/cash_entry.dart';
import '../../payment/domain/entities/payment_summary.dart';
import '../domain/entities/report_models.dart';
import 'report_print_platform.dart';

class CashierReportPrintData {
  const CashierReportPrintData({
    required this.appName,
    required this.branchName,
    required this.periodLabel,
    required this.cashierName,
    required this.dashboard,
    required this.sales,
    required this.payments,
    this.cashSummary,
    this.cashEntries = const [],
  });

  final String appName;
  final String branchName;
  final String periodLabel;
  final String cashierName;
  final DashboardSummary dashboard;
  final SalesReport sales;
  final List<PaymentSummary> payments;
  final CashLedgerSummary? cashSummary;
  final List<CashEntry> cashEntries;
}

abstract final class CashierReportPrint {
  static const _methodOrder = ['CASH', 'QRIS', 'TRANSFER', 'EDC'];

  static Map<String, double> totalsByMethod(List<PaymentSummary> payments) {
    final map = <String, double>{};
    for (final p in payments) {
      final key = p.paymentMethod.toUpperCase();
      map[key] = (map[key] ?? 0) + p.amount;
    }
    return map;
  }

  static Future<void> print(CashierReportPrintData data) async {
    await openAndPrintHtml(_buildHtml(data));
  }

  static String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static String _buildHtml(CashierReportPrintData data) {
    final timeFmt = DateFormat('dd/MM/yyyy HH:mm');
    final printedAt = timeFmt.format(DateTime.now());
    final byMethod = totalsByMethod(data.payments);
    final methodKeys = [
      ..._methodOrder.where(byMethod.containsKey),
      ...byMethod.keys.where((k) => !_methodOrder.contains(k)),
    ];

    final methodRows = methodKeys
        .map(
          (m) => '''
        <div class="summary-row">
          <span>${_escape(paymentMethodLabel(m))}</span>
          <strong>${_escape(formatRupiah(byMethod[m]!))}</strong>
        </div>''',
        )
        .join();

    final paymentRows = data.payments
        .map(
          (p) => '''
        <tr>
          <td>${_escape(p.orderNumber)}</td>
          <td>${_escape(p.customerName ?? 'Walk-in')}</td>
          <td>${_escape(paymentMethodLabel(p.paymentMethod))}</td>
          <td style="text-align:right">${_escape(formatRupiah(p.amount))}</td>
          <td>${_escape(p.paidAt != null ? timeFmt.format(p.paidAt!.toLocal()) : '-')}</td>
        </tr>''',
        )
        .join();

    final paymentsTable = data.payments.isEmpty
        ? '<p>Tidak ada pembayaran pada periode ini.</p>'
        : '''
        <table>
          <thead>
            <tr>
              <th>Order</th>
              <th>Pelanggan</th>
              <th>Metode</th>
              <th>Jumlah</th>
              <th>Waktu</th>
            </tr>
          </thead>
          <tbody>$paymentRows</tbody>
        </table>''';

    return '''
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <title>${_escape(data.appName)} — Laporan Kasir</title>
  <style>
    body { font-family: system-ui, sans-serif; padding: 24px; color: #111; max-width: 900px; margin: 0 auto; }
    h1 { font-size: 18px; margin: 0 0 4px; text-align: center; }
    h2 { font-size: 14px; margin: 0 0 16px; text-align: center; font-weight: 600; }
    h3 { font-size: 13px; margin: 16px 0 8px; }
    .meta { font-size: 12px; margin-bottom: 4px; }
    .summary-row { display: flex; justify-content: space-between; font-size: 12px; margin: 4px 0; }
    table { width: 100%; border-collapse: collapse; font-size: 11px; }
    th, td { border: 1px solid #ccc; padding: 6px 8px; }
    th { background: #f3f4f6; text-align: left; }
    @media print {
      body { padding: 12px; }
      @page { margin: 12mm; }
    }
  </style>
</head>
<body>
  <h1>${_escape(data.appName)}</h1>
  <h2>LAPORAN KASIR</h2>
  <div class="meta"><strong>Cabang:</strong> ${_escape(data.branchName)}</div>
  <div class="meta"><strong>Periode:</strong> ${_escape(data.periodLabel)}</div>
  <div class="meta"><strong>Kasir:</strong> ${_escape(data.cashierName)}</div>
  <div class="meta"><strong>Dicetak:</strong> ${_escape(printedAt)}</div>

  <h3>Ringkasan</h3>
  <div class="summary-row"><span>Total pembayaran</span><strong>${_escape(formatRupiah(data.dashboard.todaySales))}</strong></div>
  <div class="summary-row"><span>Order lunas</span><strong>${data.dashboard.todayOrders}</strong></div>
  <div class="summary-row"><span>Total penjualan (order)</span><strong>${_escape(formatRupiah(data.sales.totals.total))}</strong></div>
  ${data.cashSummary != null ? '''
  <h3>Kas cabang (manual)</h3>
  <div class="summary-row"><span>Uang masuk</span><strong>${_escape(formatRupiah(data.cashSummary!.cashIn))}</strong></div>
  <div class="summary-row"><span>Uang keluar</span><strong>${_escape(formatRupiah(data.cashSummary!.cashOut))}</strong></div>
  <div class="summary-row"><span>Net manual</span><strong>${_escape(formatRupiah(data.cashSummary!.netManual))}</strong></div>
  <div class="summary-row"><span>Total kas (penjualan + manual)</span><strong>${_escape(formatRupiah(data.cashSummary!.netTotal))}</strong></div>
  ''' : ''}
  ${methodKeys.isNotEmpty ? '''
  <h3>Per metode pembayaran</h3>
  $methodRows
  <div class="summary-row"><span>Jumlah transaksi</span><strong>${data.payments.length}</strong></div>
  ''' : ''}

  <h3>Daftar pembayaran</h3>
  $paymentsTable
  ${data.cashEntries.isNotEmpty ? '''
  <h3>Pencatatan kas manual</h3>
  <table>
    <thead>
      <tr><th>Jenis</th><th>Kategori</th><th>Jumlah</th><th>Catatan</th></tr>
    </thead>
    <tbody>
      ${data.cashEntries.map((e) {
        final sign = e.isIn ? '+' : '−';
        return '''
      <tr>
        <td>${_escape(cashEntryTypeLabel(e.type))}</td>
        <td>${_escape(e.category ?? '-')}</td>
        <td style="text-align:right">${_escape('$sign${formatRupiah(e.amount)}')}</td>
        <td>${_escape(e.notes ?? '-')}</td>
      </tr>''';
      }).join()}
    </tbody>
  </table>
  ''' : ''}
</body>
</html>''';
  }
}
