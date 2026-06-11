import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';

/// Form data resep dokter — mengikuti [AppTheme] (input filled, radius, border).
class PrescriptionFormSection extends StatefulWidget {
  const PrescriptionFormSection({
    super.key,
    required this.numberController,
    required this.doctorController,
    required this.patientController,
    required this.ageController,
    required this.notesController,
    required this.prescriptionDate,
    required this.onDateChanged,
    this.requiredFields = true,
    this.onSyncPatientFromCustomer,
    this.customerName,
  });

  final TextEditingController numberController;
  final TextEditingController doctorController;
  final TextEditingController patientController;
  final TextEditingController ageController;
  final TextEditingController notesController;
  final DateTime? prescriptionDate;
  final ValueChanged<DateTime?> onDateChanged;
  final bool requiredFields;
  final VoidCallback? onSyncPatientFromCustomer;
  final String? customerName;

  @override
  State<PrescriptionFormSection> createState() => _PrescriptionFormSectionState();
}

class _PrescriptionFormSectionState extends State<PrescriptionFormSection> {
  late final TextEditingController _dateDisplayController;

  @override
  void initState() {
    super.initState();
    _dateDisplayController = TextEditingController(text: _formatDate(widget.prescriptionDate));
  }

  @override
  void didUpdateWidget(PrescriptionFormSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prescriptionDate != widget.prescriptionDate) {
      _dateDisplayController.text = _formatDate(widget.prescriptionDate);
    }
  }

  @override
  void dispose() {
    _dateDisplayController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    return DateFormat('dd MMM yyyy', 'id_ID').format(d);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.prescriptionDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) widget.onDateChanged(picked);
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 22) : null,
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Resep Dokter',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.requiredFields
                            ? 'Isi sesuai salinan resep'
                            : 'Opsional jika membawa resep',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.requiredFields)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Text(
                      'Wajib',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: widget.numberController,
              decoration: _fieldDecoration(
                label: widget.requiredFields ? 'Nomor resep *' : 'Nomor resep',
                hint: 'RX-2025-00142',
                icon: Icons.tag_outlined,
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              readOnly: true,
              onTap: _pickDate,
              controller: _dateDisplayController,
              decoration: _fieldDecoration(
                label: widget.requiredFields ? 'Tanggal resep *' : 'Tanggal resep',
                hint: 'Pilih tanggal',
                icon: Icons.calendar_today_outlined,
                suffix: widget.prescriptionDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () => widget.onDateChanged(null),
                      )
                    : const Icon(Icons.arrow_drop_down),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: widget.doctorController,
              decoration: _fieldDecoration(
                label: widget.requiredFields ? 'Nama dokter *' : 'Nama dokter',
                hint: 'dr. Andi Wijaya',
                icon: Icons.local_hospital_outlined,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: widget.patientController,
                    decoration: _fieldDecoration(
                      label: widget.requiredFields ? 'Nama pasien *' : 'Nama pasien',
                      icon: Icons.person_outline,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: widget.ageController,
                    decoration: _fieldDecoration(
                      label: 'Umur',
                      hint: '32 thn',
                      icon: Icons.cake_outlined,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.onSyncPatientFromCustomer != null &&
                widget.customerName != null &&
                widget.customerName!.trim().length >= 2) ...[
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onSyncPatientFromCustomer,
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Samakan dengan pelanggan'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.primary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Expanded(
                    child: Text(
                      'Petunjuk penggunaan diisi per item di keranjang.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: widget.notesController,
              decoration: _fieldDecoration(
                label: 'Catatan tambahan',
                hint: 'Alergi, riwayat (opsional)',
                icon: Icons.note_alt_outlined,
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }
}
