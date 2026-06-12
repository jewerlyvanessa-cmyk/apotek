import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../features/medicine/data/medicine_repository.dart';
import '../../features/medicine/domain/entities/medicine.dart';

void _rememberBarcodeInCache(
  Map<String, Medicine> cache,
  Medicine med,
) {
  cache[med.id] = med;
  final code = med.barcode?.trim();
  if (code != null && code.isNotEmpty) {
    cache[code] = med;
  }
}

/// Cari obat by barcode; opsional pakai [cache] untuk sesi scan cepat (opname).
Future<Medicine?> findMedicineByBarcodeWithFeedback(
  BuildContext context,
  WidgetRef ref,
  String barcode, {
  Map<String, Medicine>? cache,
  bool showNotFoundSnackBar = true,
}) async {
  final normalized = barcode.trim();
  if (normalized.isEmpty) return null;

  final cached = cache?[normalized];
  if (cached != null) return cached;

  try {
    final med =
        await ref.read(medicineRepositoryProvider).findByBarcode(normalized);
    if (med != null && cache != null) {
      _rememberBarcodeInCache(cache, med);
      cache[normalized] = med;
    }
    if (med == null && showNotFoundSnackBar && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode tidak ditemukan: $normalized'),
          backgroundColor: AppColors.danger,
          duration: const Duration(milliseconds: 1200),
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
          duration: const Duration(milliseconds: 1200),
        ),
      );
    }
    return null;
  }
}
