import 'package:flutter/material.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../core/constants/drug_classification.dart';

class DrugClassificationChip extends StatelessWidget {
  const DrugClassificationChip({
    super.key,
    required this.classification,
    this.compact = false,
  });

  final DrugClassification classification;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = classification.color;
    final text = compact ? classification.shortLabel : classification.label;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 8,
            height: compact ? 6 : 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 4 : 6),
          Text(
            text,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
