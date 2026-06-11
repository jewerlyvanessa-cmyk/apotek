import 'package:flutter/material.dart';

/// Tipe produk di katalog apotek (selaras dengan API `product_type`).
enum ProductType {
  drug('DRUG', 'Obat'),
  health('HEALTH', 'Produk kesehatan'),
  commercial('COMMERCIAL', 'Produk komersial');

  const ProductType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ProductType fromApi(String? value) {
    switch (value?.toUpperCase()) {
      case 'HEALTH':
        return ProductType.health;
      case 'COMMERCIAL':
        return ProductType.commercial;
      default:
        return ProductType.drug;
    }
  }

  bool get canRequirePrescription => this == ProductType.drug;

  IconData get icon {
    switch (this) {
      case ProductType.drug:
        return Icons.medication_outlined;
      case ProductType.health:
        return Icons.health_and_safety_outlined;
      case ProductType.commercial:
        return Icons.shopping_bag_outlined;
    }
  }
}
