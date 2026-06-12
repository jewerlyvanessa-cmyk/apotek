import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/printing/printer_providers.dart';
import '../../../core/printing/thermal_printer_settings.dart';
import '../../order/domain/entities/order.dart';
import '../presentation/providers/report_date_filter.dart';
import 'branch_report_print.dart';

Future<String?> pickBranchReportPrintMode(BuildContext context) async {
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

Future<void> printBranchReport({
  required WidgetRef ref,
  required BuildContext context,
  required String branchName,
  required List<OrderSummary> orders,
}) async {
  final mode = await pickBranchReportPrintMode(context);
  if (mode == null || !context.mounted) return;

  final filter = ref.read(reportDateFilterProvider);
  final config = ref.read(appConfigProvider);
  final paid = orders.where((o) => o.status == 'PAID').length;
  final pending = orders.where((o) => o.status == 'PENDING_PHARMACY').length;
  final waiting = orders.where((o) => o.status == 'WAITING_PAYMENT').length;
  final revenue = orders
      .where((o) => o.status == 'PAID')
      .fold<double>(0, (s, o) => s + o.total);

  final data = BranchReportPrintData(
    appName: config.appName,
    branchName: branchName,
    periodLabel: filter.label(),
    totalOrders: orders.length,
    paidCount: paid,
    pendingCount: pending,
    waitingCount: waiting,
    revenue: revenue,
    orders: orders,
  );

  if (mode == 'thermal') {
    final prefs = ref.read(prefsProvider);
    final settings = await ThermalPrinterSettings.load(prefs);
    await ref.read(thermalPrinterServiceProvider).printBranchSummary(
          settings: settings,
          data: data,
        );
  } else {
    await BranchReportPrint.print(data);
  }
}
