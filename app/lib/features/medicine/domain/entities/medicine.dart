import 'package:equatable/equatable.dart';
import '../../../../core/constants/product_type.dart';

class Medicine extends Equatable {
  const Medicine({
    required this.id,
    required this.name,
    required this.buyPrice,
    required this.sellPrice,
    required this.unit,
    required this.minStock,
    this.barcode,
    this.sku,
    this.imageUrl,
    this.categoryId,
    this.categoryName,
    this.supplierId,
    this.supplierName,
    this.productTypeId,
    this.productTypeCode,
    this.productTypeName,
    this.productTypeAllowsPrescription = false,
    this.requiresPrescription = false,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? barcode;
  final String? sku;
  final String? imageUrl;
  final double buyPrice;
  final double sellPrice;
  final String unit;
  final int minStock;
  final String? categoryId;
  final String? categoryName;
  final String? supplierId;
  final String? supplierName;
  final String? productTypeId;
  final String? productTypeCode;
  final String? productTypeName;
  final bool productTypeAllowsPrescription;
  final bool requiresPrescription;
  final bool isActive;

  ProductType get productType => ProductType.fromApi(productTypeCode);

  String get productTypeLabel => productTypeName ?? productType.label;

  factory Medicine.fromJson(Map<String, dynamic> json) {
    final pt = json['productType'] ?? json['product_type'];
    String? typeCode;
    String? typeName;
    String? typeId;
    bool typeAllowsRx = false;

    if (pt is Map<String, dynamic>) {
      typeId = pt['id'] as String?;
      typeCode = pt['code'] as String?;
      typeName = pt['name'] as String?;
      typeAllowsRx = pt['allowsPrescription'] as bool? ??
          pt['allows_prescription'] as bool? ??
          false;
    } else if (pt is String) {
      typeCode = pt;
    }

    typeCode ??= json['productTypeCode'] as String? ??
        json['product_type_code'] as String?;
    typeId ??=
        json['productTypeId'] as String? ?? json['product_type_id'] as String?;

    return Medicine(
      id: json['id'] as String,
      name: json['name'] as String,
      barcode: json['barcode'] as String?,
      sku: json['sku'] as String?,
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      buyPrice: _toDouble(json['buyPrice'] ?? json['buy_price']),
      sellPrice: _toDouble(json['sellPrice'] ?? json['sell_price']),
      unit: json['unit'] as String? ?? 'STRIP',
      minStock: json['minStock'] as int? ?? json['min_stock'] as int? ?? 0,
      categoryId: json['categoryId'] as String? ?? json['category_id'] as String?,
      categoryName: (json['category'] as Map<String, dynamic>?)?['name'] as String?,
      supplierId: json['supplierId'] as String? ?? json['supplier_id'] as String?,
      supplierName: (json['supplier'] as Map<String, dynamic>?)?['name'] as String?,
      productTypeId: typeId,
      productTypeCode: typeCode,
      productTypeName: typeName,
      productTypeAllowsPrescription: typeAllowsRx,
      requiresPrescription: json['requiresPrescription'] as bool? ??
          json['requires_prescription'] as bool? ??
          false,
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  @override
  List<Object?> get props => [id, name, barcode, sellPrice, imageUrl];
}
