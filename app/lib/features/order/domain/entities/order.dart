import 'package:equatable/equatable.dart';
import '../../../../core/constants/product_type.dart';
import 'prescription_info.dart';

class OrderSummary extends Equatable {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
    this.customerName,
    this.customerId,
    this.servedById,
    this.createdAt,
    this.itemCount = 0,
    this.items = const [],
    this.prescriptionNotes,
    this.pharmacistNotes,
    this.pharmacistApprovedAt,
    this.prescription,
    this.branchId,
    this.branchName,
  });

  final String id;
  final String orderNumber;
  final String status;
  final double total;
  final String? branchId;
  final String? branchName;
  final String? customerName;
  final String? customerId;
  final String? servedById;
  final DateTime? createdAt;
  final int itemCount;
  final List<OrderLineItem> items;
  final String? prescriptionNotes;
  final String? pharmacistNotes;
  final DateTime? pharmacistApprovedAt;
  final PrescriptionInfo? prescription;

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    return OrderSummary(
      id: json['id'] as String,
      orderNumber: json['orderNumber'] as String? ?? json['order_number'] as String,
      status: json['status'] as String,
      total: _toDouble(json['total']),
      branchId: json['branchId'] as String? ??
          json['branch_id'] as String? ??
          (json['branch'] as Map<String, dynamic>?)?['id'] as String?,
      branchName: (json['branch'] as Map<String, dynamic>?)?['name'] as String?,
      customerName: json['customerName'] as String? ?? json['customer_name'] as String?,
      customerId: json['customerId'] as String? ??
          json['customer_id'] as String? ??
          (json['customer'] as Map<String, dynamic>?)?['id'] as String?,
      servedById: json['servedById'] as String? ??
          json['served_by'] as String? ??
          (json['servedBy'] as Map<String, dynamic>?)?['id'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      itemCount: itemsJson.length,
      items: itemsJson
          .map((e) => OrderLineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      prescriptionNotes: json['prescriptionNotes'] as String? ??
          json['prescription_notes'] as String?,
      pharmacistNotes: json['pharmacistNotes'] as String? ??
          json['pharmacist_notes'] as String?,
      pharmacistApprovedAt: () {
        final raw = json['pharmacistApprovedAt'] ?? json['pharmacist_approved_at'];
        return raw != null ? DateTime.tryParse(raw.toString()) : null;
      }(),
      prescription: () {
        final rx = PrescriptionInfo.fromOrderJson(json);
        return rx.hasAnyData ? rx : null;
      }(),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  @override
  List<Object?> get props => [id, orderNumber, status];
}

class OrderLineItem extends Equatable {
  const OrderLineItem({
    required this.medicineId,
    required this.medicineName,
    required this.quantity,
    required this.price,
    required this.subtotal,
    this.unit,
    this.usageInstructions,
    this.productType = ProductType.drug,
    this.requiresPrescription = false,
  });

  final String medicineId;
  final String medicineName;
  final int quantity;
  final double price;
  final double subtotal;
  final String? unit;
  final String? usageInstructions;
  final ProductType productType;
  final bool requiresPrescription;

  factory OrderLineItem.fromJson(Map<String, dynamic> json) {
    final med = json['medicine'] as Map<String, dynamic>?;
    return OrderLineItem(
      medicineId: json['medicineId'] as String? ?? json['medicine_id'] as String,
      medicineName: med?['name'] as String? ?? '',
      quantity: json['quantity'] as int,
      price: OrderSummary._toDouble(json['price']),
      subtotal: OrderSummary._toDouble(json['subtotal']),
      unit: med?['unit'] as String?,
      usageInstructions: json['notes'] as String?,
      productType: _parseProductType(med),
      requiresPrescription: med?['requiresPrescription'] as bool? ??
          med?['requires_prescription'] as bool? ??
          false,
    );
  }

  @override
  List<Object?> get props => [medicineId, quantity];
}

class CartItem extends Equatable {
  const CartItem({
    required this.medicineId,
    required this.name,
    required this.sellPrice,
    required this.quantity,
    this.availableStock = 0,
    this.unit,
    this.rackPosition,
    this.productType = ProductType.drug,
    this.requiresPrescription = false,
    this.usageInstructions,
  });

  final String medicineId;
  final String name;
  final double sellPrice;
  final int quantity;
  final int availableStock;
  final String? unit;
  final String? rackPosition;
  final ProductType productType;
  final bool requiresPrescription;
  final String? usageInstructions;

  double get subtotal => sellPrice * quantity;

  CartItem copyWith({
    int? quantity,
    int? availableStock,
    String? rackPosition,
    ProductType? productType,
    bool? requiresPrescription,
    String? usageInstructions,
  }) {
    return CartItem(
      medicineId: medicineId,
      name: name,
      sellPrice: sellPrice,
      quantity: quantity ?? this.quantity,
      availableStock: availableStock ?? this.availableStock,
      unit: unit,
      rackPosition: rackPosition ?? this.rackPosition,
      productType: productType ?? this.productType,
      requiresPrescription:
          requiresPrescription ?? this.requiresPrescription,
      usageInstructions: usageInstructions ?? this.usageInstructions,
    );
  }

  @override
  List<Object?> get props => [medicineId, quantity];
}

ProductType _parseProductType(Map<String, dynamic>? med) {
  if (med == null) return ProductType.drug;
  final pt = med['productType'] ?? med['product_type'];
  if (pt is Map<String, dynamic>) {
    return ProductType.fromApi(pt['code'] as String?);
  }
  if (pt is String) return ProductType.fromApi(pt);
  return ProductType.drug;
}
