import 'package:equatable/equatable.dart';
import '../../../../core/constants/product_type.dart';

class ProductTypeDef extends Equatable {
  const ProductTypeDef({
    required this.id,
    required this.code,
    required this.name,
    this.allowsPrescription = false,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String code;
  final String name;
  final bool allowsPrescription;
  final bool isActive;
  final int sortOrder;

  ProductType get legacyType => ProductType.fromApi(code);

  factory ProductTypeDef.fromJson(Map<String, dynamic> json) {
    return ProductTypeDef(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      allowsPrescription: json['allowsPrescription'] as bool? ??
          json['allows_prescription'] as bool? ??
          false,
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? json['sort_order'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, code, name];
}

class MedicineCategory extends Equatable {
  const MedicineCategory({required this.id, required this.name});

  final String id;
  final String name;

  factory MedicineCategory.fromJson(Map<String, dynamic> json) {
    return MedicineCategory(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  @override
  List<Object?> get props => [id, name];
}

class MedicineUnit extends Equatable {
  const MedicineUnit({required this.id, required this.name});

  final String id;
  final String name;

  factory MedicineUnit.fromJson(Map<String, dynamic> json) {
    return MedicineUnit(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  @override
  List<Object?> get props => [id, name];
}

class Supplier extends Equatable {
  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, name];
}
