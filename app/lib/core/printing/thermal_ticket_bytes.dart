import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:intl/intl.dart';
import '../../shared/utils/currency_formatter.dart';
import '../../features/order/domain/entities/order.dart';
import '../../features/order/presentation/utils/order_status_ui.dart';
import '../../features/payment/domain/entities/payment_summary.dart';
import '../../features/reports/utils/branch_report_print.dart';
import '../../features/reports/utils/cashier_report_print.dart';

class ThermalTicketBytes {
  static Future<List<int>> receipt({
    required String appName,
    required String? branchName,
    required OrderSummary order,
    required String paymentMethod,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];

    bytes.addAll(
      generator.text(appName, styles: const PosStyles(align: PosAlign.center, bold: true)),
    );
    if (branchName != null && branchName.trim().isNotEmpty) {
      bytes.addAll(
        generator.text(branchName, styles: const PosStyles(align: PosAlign.center)),
      );
    }
    bytes.addAll(generator.hr());

    bytes.addAll(generator.row([
      PosColumn(text: 'Order', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: order.orderNumber, width: 8),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Waktu', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(
        text: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
        width: 8,
      ),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Metode', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: paymentMethod, width: 8),
    ]));
    if (order.customerName != null && order.customerName!.trim().isNotEmpty) {
      bytes.addAll(generator.row([
        PosColumn(text: 'Pelanggan', width: 4, styles: const PosStyles(bold: true)),
        PosColumn(text: order.customerName!.trim(), width: 8),
      ]));
    }

    bytes.addAll(generator.hr());

    for (final item in order.items) {
      bytes.addAll(
        generator.text(item.medicineName, styles: const PosStyles(bold: true)),
      );
      bytes.addAll(generator.row([
        PosColumn(text: '${item.quantity} x ${formatRupiah(item.price)}', width: 8),
        PosColumn(
          text: formatRupiah(item.subtotal),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }

    bytes.addAll(generator.hr());
    bytes.addAll(generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: formatRupiah(order.total),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]));
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text('Terima kasih', styles: const PosStyles(align: PosAlign.center)),
    );
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return bytes;
  }

  static Future<List<int>> testPage({required String appName}) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];

    bytes.addAll(
      generator.text(appName, styles: const PosStyles(align: PosAlign.center, bold: true)),
    );
    bytes.addAll(
      generator.text('UJI CETAK', styles: const PosStyles(align: PosAlign.center, bold: true)),
    );
    bytes.addAll(generator.text(
      DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text('Printer siap dipakai.', styles: const PosStyles(align: PosAlign.center)),
    );
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return bytes;
  }

  static Future<List<int>> cashierReport(CashierReportPrintData data) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final timeFmt = DateFormat('dd/MM/yyyy HH:mm');
    final byMethod = CashierReportPrint.totalsByMethod(data.payments);
    final bytes = <int>[];

    bytes.addAll(
      generator.text(data.appName, styles: const PosStyles(align: PosAlign.center, bold: true)),
    );
    bytes.addAll(
      generator.text('LAPORAN KASIR', styles: const PosStyles(align: PosAlign.center, bold: true)),
    );
    bytes.addAll(
      generator.text(data.branchName, styles: const PosStyles(align: PosAlign.center)),
    );
    bytes.addAll(
      generator.text(data.periodLabel, styles: const PosStyles(align: PosAlign.center)),
    );
    bytes.addAll(generator.hr());

    bytes.addAll(generator.text('Ringkasan', styles: const PosStyles(bold: true)));
    bytes.addAll(generator.row([
      PosColumn(text: 'Pembayaran', width: 6),
      PosColumn(
        text: formatRupiah(data.dashboard.todaySales),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Order lunas', width: 6),
      PosColumn(
        text: '${data.dashboard.todayOrders}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Penjualan', width: 6),
      PosColumn(
        text: formatRupiah(data.sales.totals.total),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
    bytes.addAll(generator.hr());

    if (byMethod.isNotEmpty) {
      bytes.addAll(generator.text('Per metode', styles: const PosStyles(bold: true)));
      for (final entry in byMethod.entries) {
        bytes.addAll(generator.row([
          PosColumn(text: paymentMethodLabel(entry.key), width: 6),
          PosColumn(
            text: formatRupiah(entry.value),
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]));
      }
      bytes.addAll(generator.hr());
    }

    bytes.addAll(
      generator.text('Pembayaran (${data.payments.length})', styles: const PosStyles(bold: true)),
    );
    for (final p in data.payments.take(40)) {
      bytes.addAll(generator.text(p.orderNumber, styles: const PosStyles(bold: true)));
      bytes.addAll(generator.row([
        PosColumn(text: paymentMethodLabel(p.paymentMethod), width: 6),
        PosColumn(
          text: formatRupiah(p.amount),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
      if (p.paidAt != null) {
        bytes.addAll(generator.text(
          timeFmt.format(p.paidAt!.toLocal()),
          styles: const PosStyles(fontType: PosFontType.fontB),
        ));
      }
    }
    if (data.payments.length > 40) {
      bytes.addAll(generator.text('... +${data.payments.length - 40} lainnya'));
    }

    bytes.addAll(generator.hr());
    bytes.addAll(generator.text(
      'Dicetak ${timeFmt.format(DateTime.now())}',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return bytes;
  }

  static Future<List<int>> branchSummary(BranchReportPrintData data) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final timeFmt = DateFormat('dd/MM/yyyy HH:mm');
    final bytes = <int>[];

    bytes.addAll(
      generator.text(data.appName, styles: const PosStyles(align: PosAlign.center, bold: true)),
    );
    bytes.addAll(
      generator.text('LAPORAN CABANG', styles: const PosStyles(align: PosAlign.center, bold: true)),
    );
    bytes.addAll(
      generator.text(data.branchName, styles: const PosStyles(align: PosAlign.center)),
    );
    bytes.addAll(
      generator.text(data.periodLabel, styles: const PosStyles(align: PosAlign.center)),
    );
    bytes.addAll(generator.hr());

    bytes.addAll(generator.row([
      PosColumn(text: 'Total order', width: 6),
      PosColumn(
        text: '${data.totalOrders}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Lunas', width: 6),
      PosColumn(
        text: '${data.paidCount}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Omzet', width: 6),
      PosColumn(
        text: formatRupiah(data.revenue),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
    bytes.addAll(generator.hr());

    for (final o in data.orders.take(30)) {
      bytes.addAll(generator.text(o.orderNumber, styles: const PosStyles(bold: true)));
      bytes.addAll(generator.row([
        PosColumn(text: orderStatusLabel(o.status), width: 6),
        PosColumn(
          text: formatRupiah(o.total),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }
    if (data.orders.length > 30) {
      bytes.addAll(generator.text('... +${data.orders.length - 30} lainnya'));
    }

    bytes.addAll(generator.hr());
    bytes.addAll(generator.text(
      'Dicetak ${timeFmt.format(DateTime.now())}',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return bytes;
  }
}
