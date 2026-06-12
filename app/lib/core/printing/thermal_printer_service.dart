import '../../features/order/domain/entities/order.dart';
import '../../features/reports/utils/branch_report_print.dart';
import '../../features/reports/utils/cashier_report_print.dart';
import 'thermal_printer_settings.dart';
import 'thermal_printer_transport.dart';
import 'thermal_ticket_bytes.dart';

class ThermalPrinterService {
  ThermalPrinterService(this._transport);

  final ThermalPrinterTransport _transport;

  Future<void> printReceipt({
    required ThermalPrinterSettings settings,
    required String appName,
    required String? branchName,
    required OrderSummary order,
    required String paymentMethod,
  }) async {
    final bytes = await ThermalTicketBytes.receipt(
      appName: appName,
      branchName: branchName,
      order: order,
      paymentMethod: paymentMethod,
    );
    await _transport.send(settings, bytes);
  }

  Future<void> printCashierReport({
    required ThermalPrinterSettings settings,
    required CashierReportPrintData data,
  }) async {
    final bytes = await ThermalTicketBytes.cashierReport(data);
    await _transport.send(settings, bytes);
  }

  Future<void> printTestPage({
    required ThermalPrinterSettings settings,
    required String appName,
  }) async {
    final bytes = await ThermalTicketBytes.testPage(appName: appName);
    await _transport.send(settings, bytes);
  }

  Future<void> printBranchSummary({
    required ThermalPrinterSettings settings,
    required BranchReportPrintData data,
  }) async {
    final bytes = await ThermalTicketBytes.branchSummary(data);
    await _transport.send(settings, bytes);
  }
}
