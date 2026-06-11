import 'package:equatable/equatable.dart';
import '../../../order/domain/entities/order.dart';

class PaymentSummary extends Equatable {
  const PaymentSummary({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.amount,
    required this.paymentMethod,
    this.referenceNumber,
    this.amountReceived,
    this.changeAmount,
    this.proofImageUrl,
    this.paidAt,
    this.paidByName,
    this.customerName,
    this.order,
  });

  final String id;
  final String orderId;
  final String orderNumber;
  final double amount;
  final String paymentMethod;
  final String? referenceNumber;
  final double? amountReceived;
  final double? changeAmount;
  final String? proofImageUrl;
  final DateTime? paidAt;
  final String? paidByName;
  final String? customerName;
  final OrderSummary? order;

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    final orderJson = json['order'] as Map<String, dynamic>?;
    return PaymentSummary(
      id: json['id'] as String,
      orderId: json['orderId'] as String? ??
          json['order_id'] as String? ??
          orderJson?['id'] as String? ??
          '',
      orderNumber: orderJson?['orderNumber'] as String? ??
          orderJson?['order_number'] as String? ??
          '',
      amount: _toDouble(json['amount']),
      paymentMethod: json['paymentMethod'] as String? ??
          json['payment_method'] as String? ??
          '',
      referenceNumber: json['referenceNumber'] as String? ??
          json['reference_number'] as String?,
      amountReceived: _optionalDouble(
        json['amountReceived'] ?? json['amount_received'],
      ),
      changeAmount: _optionalDouble(
        json['changeAmount'] ?? json['change_amount'],
      ),
      proofImageUrl: json['proofImageUrl'] as String? ??
          json['proof_image_url'] as String?,
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'].toString())
          : json['paid_at'] != null
              ? DateTime.tryParse(json['paid_at'].toString())
              : null,
      paidByName: (json['paidBy'] as Map<String, dynamic>?)?['fullName']
              as String? ??
          (json['paid_by'] as Map<String, dynamic>?)?['full_name'] as String?,
      customerName: orderJson?['customerName'] as String? ??
          orderJson?['customer_name'] as String?,
      order: orderJson != null && orderJson.containsKey('items')
          ? OrderSummary.fromJson(orderJson)
          : null,
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static double? _optionalDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  @override
  List<Object?> get props => [id, orderId, orderNumber];
}

String paymentMethodLabel(String method) {
  switch (method.toUpperCase()) {
    case 'CASH':
      return 'Tunai';
    case 'QRIS':
      return 'QRIS';
    case 'TRANSFER':
      return 'Transfer';
    case 'EDC':
      return 'EDC / Kartu';
    default:
      return method;
  }
}
