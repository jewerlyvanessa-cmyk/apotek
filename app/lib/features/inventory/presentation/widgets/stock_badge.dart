import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/stock_item.dart';

class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.item});

  final StockItem item;

  Color get _color {
    switch (item.status) {
      case StockStatus.ok:
        return AppColors.stockOk;
      case StockStatus.low:
        return AppColors.stockLow;
      case StockStatus.outOfStock:
        return AppColors.stockOut;
    }
  }

  String get _label {
    switch (item.status) {
      case StockStatus.ok:
        return 'Aman';
      case StockStatus.low:
        return 'Menipis';
      case StockStatus.outOfStock:
        return 'Habis';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${item.availableQuantity}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _color,
              fontSize: 14,
              height: 1.1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            _label,
            style: TextStyle(fontSize: 9, color: _color, height: 1.1),
          ),
          if (item.reservedQuantity > 0)
            Text(
              'R ${item.reservedQuantity}',
              style: const TextStyle(
                fontSize: 8,
                color: AppColors.textSecondary,
                height: 1.1,
              ),
            ),
        ],
      ),
    );
  }
}
