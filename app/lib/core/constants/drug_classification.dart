import 'package:flutter/material.dart';

/// Golongan obat (lingkaran warna pada kemasan) — selaras dengan API.
enum DrugClassification {
  prescription('PRESCRIPTION', 'Obat Keras', Color(0xFFB91C1C)),
  limitedOtc('LIMITED_OTC', 'Bebas Terbatas', Color(0xFF0369A1)),
  otc('OTC', 'Obat Bebas', Color(0xFF15803D)),
  controlled('CONTROLLED', 'Narkotika/Psikotropika', Color(0xFF0F172A));

  const DrugClassification(this.apiValue, this.label, this.color);

  final String apiValue;
  final String label;
  final Color color;

  bool get requiresPrescription =>
      this == DrugClassification.prescription ||
      this == DrugClassification.controlled;

  String get shortLabel => switch (this) {
        DrugClassification.prescription => 'Keras',
        DrugClassification.limitedOtc => 'Terbatas',
        DrugClassification.otc => 'Bebas',
        DrugClassification.controlled => 'Narkotika',
      };

  static DrugClassification? fromApi(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final item in DrugClassification.values) {
      if (item.apiValue == value.toUpperCase()) return item;
    }
    return null;
  }

  static List<DrugClassification> get catalogOptions => DrugClassification.values;
}
