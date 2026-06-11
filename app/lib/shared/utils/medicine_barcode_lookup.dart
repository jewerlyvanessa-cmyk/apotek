import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../features/medicine/data/medicine_repository.dart';
import '../../features/medicine/domain/entities/medicine.dart';

/// Cari obat by barcode; tampilkan snackbar jika tidak ada.
Future<Medicine?> findMedicineByBarcodeWithFeedback(
  BuildContext context,
  WidgetRef ref,
  String barcode,
) async {
  try {
    final med = await ref.read(medicineRepositoryProvider).findByBarcode(barcode);
    if (med == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode tidak ditemukan: $barcode'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
    return med;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
    return null;
  }
}
