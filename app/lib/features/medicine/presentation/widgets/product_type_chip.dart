import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../core/constants/product_type.dart';

class ProductTypeChip extends StatelessWidget {
  const ProductTypeChip({
    super.key,
    required this.type,
    this.label,
    this.compact = false,
  });

  final ProductType type;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      ProductType.drug => AppColors.primary,
      ProductType.health => AppColors.success,
      ProductType.commercial => AppColors.textSecondary,
    };

    final text = label ?? (compact ? _shortLabel(type) : type.label);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _shortLabel(ProductType type) {
    return switch (type) {
      ProductType.drug => 'Obat',
      ProductType.health => 'Kesehatan',
      ProductType.commercial => 'Komersial',
    };
  }
}
