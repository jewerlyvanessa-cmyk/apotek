import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

String orderStatusLabel(String status) {
  switch (status) {
    case 'PENDING_PHARMACY':
      return 'Telaah apoteker';
    case 'WAITING_PAYMENT':
      return 'Menunggu bayar';
    case 'WAITING_QRIS':
      return 'Menunggu QRIS';
    case 'PAID':
      return 'Lunas';
    case 'CANCELLED':
      return 'Batal';
    case 'REFUNDED':
      return 'Retur';
    default:
      return status;
  }
}

Color orderStatusColor(String status) {
  switch (status) {
    case 'PAID':
      return AppColors.success;
    case 'CANCELLED':
    case 'REFUNDED':
      return AppColors.danger;
    case 'PENDING_PHARMACY':
      return Colors.orange;
    default:
      return AppColors.primary;
  }
}
