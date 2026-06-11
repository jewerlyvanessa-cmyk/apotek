import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../pages/barcode_scanner_page.dart';

/// Buka kamera scanner; mengembalikan barcode atau null jika dibatalkan.
Future<String?> openBarcodeScanner(BuildContext context) {
  return Navigator.of(context).push<String?>(
    MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
  );
}

/// Mode berkelanjutan — memanggil [onBarcode] tiap scan hingga user tap Selesai.
Future<void> openContinuousBarcodeScanner(
  BuildContext context, {
  required Future<void> Function(String barcode) onBarcode,
  String? title,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => BarcodeScannerPage(
        continuous: true,
        title: title,
        onBarcodeScanned: onBarcode,
      ),
    ),
  );
}

/// Field pencarian dengan tombol scan barcode di suffix.
class BarcodeSearchField extends StatelessWidget {
  const BarcodeSearchField({
    super.key,
    required this.controller,
    required this.onBarcode,
    this.hintText,
    this.labelText,
    this.isDense = false,
    this.autofocus = false,
    this.onSubmitted,
    this.onChanged,
    this.showClearButton = true,
  });

  final TextEditingController controller;
  final Future<void> Function(String barcode) onBarcode;
  final String? hintText;
  final String? labelText;
  final bool isDense;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool showClearButton;

  Future<void> _scan(BuildContext context) async {
    final code = await openBarcodeScanner(context);
    final barcode = (code ?? '').trim();
    if (barcode.isEmpty) return;
    controller.text = barcode;
    onChanged?.call(barcode);
    await onBarcode(barcode);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return Semantics(
          label: labelText ?? hintText ?? 'Pencarian barcode',
          textField: true,
          child: TextField(
          controller: controller,
          autofocus: autofocus,
          decoration: InputDecoration(
            hintText: hintText,
            labelText: labelText,
            helperText: 'Scanner USB/HID: arahkan ke field lalu scan (Enter otomatis)',
            helperMaxLines: 2,
            prefixIcon: const Icon(Icons.search),
            isDense: isDense,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'Scan barcode kamera',
                  button: true,
                  child: IconButton(
                  tooltip: 'Scan barcode',
                  icon: const Icon(Icons.qr_code_scanner),
                  color: AppColors.primary,
                  onPressed: () => _scan(context),
                ),
                ),
                if (showClearButton && value.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Hapus',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                    },
                  ),
              ],
            ),
          ),
          onSubmitted: onSubmitted,
          onChanged: onChanged,
        ),
        );
      },
    );
  }
}
