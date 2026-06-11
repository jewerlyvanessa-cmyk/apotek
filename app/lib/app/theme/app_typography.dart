import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  static const _tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        color: AppColors.textPrimary,
        height: 1.45,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: AppColors.textPrimary,
        height: 1.4,
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: AppColors.textSecondary,
        height: 1.35,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  /// Angka stok, harga, qty — lebar digit konsisten.
  static TextStyle numeric(BuildContext context, {double size = 16}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      fontFeatures: _tabular,
      height: 1.2,
    );
  }
}
