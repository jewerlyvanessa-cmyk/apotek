import '../../../order/domain/entities/order.dart';

class CustomerTransactionSummary {
  const CustomerTransactionSummary({
    required this.transactionCount,
    required this.paidCount,
    required this.totalSpent,
  });

  final int transactionCount;
  final int paidCount;
  final double totalSpent;

  factory CustomerTransactionSummary.fromJson(Map<String, dynamic> json) {
    return CustomerTransactionSummary(
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
      paidCount: (json['paid_count'] as num?)?.toInt() ?? 0,
      totalSpent: _toDouble(json['total_spent']),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}

class CustomerTransactionsResult {
  const CustomerTransactionsResult({
    required this.customer,
    required this.summary,
    required this.orders,
    required this.meta,
  });

  final Map<String, dynamic> customer;
  final CustomerTransactionSummary summary;
  final List<OrderSummary> orders;
  final Map<String, dynamic> meta;
}
