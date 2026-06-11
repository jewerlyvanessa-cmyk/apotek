import 'package:flutter/material.dart';

/// Palet Clinical Trust — tenang, bersih, cocok operasional apotek.
abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF0D9488);
  static const primaryDark = Color(0xFF0F766E);
  static const primaryLight = Color(0xFF14B8A6);
  static const primaryContainer = Color(0xFFCCFBF1);
  static const onPrimary = Colors.white;

  // Netral
  static const secondary = Color(0xFF475569);
  static const background = Color(0xFFF1F5F9);
  static const surface = Colors.white;
  static const surfaceVariant = Color(0xFFF8FAFC);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const divider = Color(0xFFCBD5E1);

  // Semantik operasional
  static const success = Color(0xFF15803D);
  static const successContainer = Color(0xFFDCFCE7);
  static const warning = Color(0xFFD97706);
  static const warningContainer = Color(0xFFFEF3C7);
  static const danger = Color(0xFFB91C1C);
  static const dangerContainer = Color(0xFFFEE2E2);
  static const info = Color(0xFF0369A1);
  static const infoContainer = Color(0xFFE0F2FE);

  // Domain apotek
  static const stockOk = success;
  static const stockLow = warning;
  static const stockOut = danger;
  static const expired = danger;
  static const prescription = info;
}
