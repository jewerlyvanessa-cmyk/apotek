import 'dart:async';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:intl/intl.dart';
import '../../shared/utils/currency_formatter.dart';
import '../../features/order/domain/entities/order.dart';
import '../../features/order/presentation/utils/order_status_ui.dart';
import '../../features/payment/domain/entities/payment_summary.dart';
import '../../features/reports/utils/branch_report_print.dart';
import '../../features/reports/utils/cashier_report_print.dart';

class ThermalPrinterService {
  Future<void> printReceipt({
    required String host,
    required int port,
    required String appName,
    required String? branchName,
    required OrderSummary order,
    required String paymentMethod,
  }) async {
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm58, profile);

    final res = await printer.connect(host, port: port, timeout: const Duration(seconds: 5));
    if (res != PosPrintResult.success) {
      throw Exception('Printer connect failed: $res');
    }

    printer.text(appName, styles: const PosStyles(align: PosAlign.center, bold: true));
    if (branchName != null && branchName.trim().isNotEmpty) {
      printer.text(branchName, styles: const PosStyles(align: PosAlign.center));
    }
    printer.hr();

    printer.row([
      PosColumn(text: 'Order', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: order.orderNumber, width: 8),
    ]);
    printer.row([
      PosColumn(text: 'Waktu', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(
        text: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
        width: 8,
      ),
    ]);
    printer.row([
      PosColumn(text: 'Metode', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: paymentMethod, width: 8),
    ]);
    if (order.customerName != null && order.customerName!.trim().isNotEmpty) {
      printer.row([
        PosColumn(text: 'Pelanggan', width: 4, styles: const PosStyles(bold: true)),
        PosColumn(text: order.customerName!.trim(), width: 8),
      ]);
    }

    printer.hr();

    for (final item in order.items) {
      printer.text(
        item.medicineName,
        styles: const PosStyles(bold: true),
      );
      printer.row([
        PosColumn(text: '${item.quantity} x ${formatRupiah(item.price)}', width: 8),
        PosColumn(
          text: formatRupiah(item.subtotal),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    printer.hr();
    printer.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: formatRupiah(order.total),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    printer.hr();

    printer.text('Terima kasih', styles: const PosStyles(align: PosAlign.center));
    printer.feed(2);
    printer.cut();
    printer.disconnect();
  }

  Future<void> printCashierReport({
    required String host,
    required int port,
    required CashierReportPrintData data,
  }) async {
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm58, profile);
    final timeFmt = DateFormat('dd/MM/yyyy HH:mm');
    final byMethod = CashierReportPrint.totalsByMethod(data.payments);

    final res = await printer.connect(host, port: port, timeout: const Duration(seconds: 5));
    if (res != PosPrintResult.success) {
      throw Exception('Printer connect failed: $res');
    }

    printer.text(data.appName, styles: const PosStyles(align: PosAlign.center, bold: true));
    printer.text('LAPORAN KASIR', styles: const PosStyles(align: PosAlign.center, bold: true));
    printer.text(data.branchName, styles: const PosStyles(align: PosAlign.center));
    printer.text(data.periodLabel, styles: const PosStyles(align: PosAlign.center));
    printer.hr();

    printer.text('Ringkasan', styles: const PosStyles(bold: true));
    printer.row([
      PosColumn(text: 'Pembayaran', width: 6),
      PosColumn(
        text: formatRupiah(data.dashboard.todaySales),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    printer.row([
      PosColumn(text: 'Order lunas', width: 6),
      PosColumn(
        text: '${data.dashboard.todayOrders}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    printer.row([
      PosColumn(text: 'Penjualan', width: 6),
      PosColumn(
        text: formatRupiah(data.sales.totals.total),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    printer.hr();

    if (byMethod.isNotEmpty) {
      printer.text('Per metode', styles: const PosStyles(bold: true));
      for (final entry in byMethod.entries) {
        printer.row([
          PosColumn(text: paymentMethodLabel(entry.key), width: 6),
          PosColumn(
            text: formatRupiah(entry.value),
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }
      printer.hr();
    }

    printer.text('Pembayaran (${data.payments.length})', styles: const PosStyles(bold: true));
    for (final p in data.payments.take(40)) {
      printer.text(p.orderNumber, styles: const PosStyles(bold: true));
      printer.row([
        PosColumn(
          text: paymentMethodLabel(p.paymentMethod),
          width: 6,
        ),
        PosColumn(
          text: formatRupiah(p.amount),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      if (p.paidAt != null) {
        printer.text(
          timeFmt.format(p.paidAt!.toLocal()),
          styles: const PosStyles(fontType: PosFontType.fontB),
        );
      }
    }
    if (data.payments.length > 40) {
      printer.text('... +${data.payments.length - 40} lainnya');
    }

    printer.hr();
    printer.text(
      'Dicetak ${timeFmt.format(DateTime.now())}',
      styles: const PosStyles(align: PosAlign.center),
    );
    printer.feed(2);
    printer.cut();
    printer.disconnect();
  }

  Future<void> printTestPage({
    required String host,
    required int port,
    required String appName,
  }) async {
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm58, profile);
    final res = await printer.connect(
      host,
      port: port,
      timeout: const Duration(seconds: 5),
    );
    if (res != PosPrintResult.success) {
      throw Exception('Printer connect failed: $res');
    }

    printer.text(appName, styles: const PosStyles(align: PosAlign.center, bold: true));
    printer.text('UJI CETAK', styles: const PosStyles(align: PosAlign.center, bold: true));
    printer.text(
      DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
      styles: const PosStyles(align: PosAlign.center),
    );
    printer.hr();
    printer.text('Printer siap dipakai.', styles: const PosStyles(align: PosAlign.center));
    printer.feed(2);
    printer.cut();
    printer.disconnect();
  }

  Future<void> printBranchSummary({
    required String host,
    required int port,
    required BranchReportPrintData data,
  }) async {
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm58, profile);
    final timeFmt = DateFormat('dd/MM/yyyy HH:mm');

    final res = await printer.connect(
      host,
      port: port,
      timeout: const Duration(seconds: 5),
    );
    if (res != PosPrintResult.success) {
      throw Exception('Printer connect failed: $res');
    }

    printer.text(data.appName, styles: const PosStyles(align: PosAlign.center, bold: true));
    printer.text('LAPORAN CABANG', styles: const PosStyles(align: PosAlign.center, bold: true));
    printer.text(data.branchName, styles: const PosStyles(align: PosAlign.center));
    printer.text(data.periodLabel, styles: const PosStyles(align: PosAlign.center));
    printer.hr();

    printer.row([
      PosColumn(text: 'Total order', width: 6),
      PosColumn(
        text: '${data.totalOrders}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    printer.row([
      PosColumn(text: 'Lunas', width: 6),
      PosColumn(
        text: '${data.paidCount}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    printer.row([
      PosColumn(text: 'Omzet', width: 6),
      PosColumn(
        text: formatRupiah(data.revenue),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    printer.hr();

    for (final o in data.orders.take(30)) {
      printer.text(o.orderNumber, styles: const PosStyles(bold: true));
      printer.row([
        PosColumn(text: orderStatusLabel(o.status), width: 6),
        PosColumn(
          text: formatRupiah(o.total),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    if (data.orders.length > 30) {
      printer.text('... +${data.orders.length - 30} lainnya');
    }

    printer.hr();
    printer.text(
      'Dicetak ${timeFmt.format(DateTime.now())}',
      styles: const PosStyles(align: PosAlign.center),
    );
    printer.feed(2);
    printer.cut();
    printer.disconnect();
  }
}

