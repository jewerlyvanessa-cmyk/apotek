import 'package:intl/intl.dart';

/// Data resep dokter pada order.
class PrescriptionInfo {
  const PrescriptionInfo({
    this.number,
    this.date,
    this.doctorName,
    this.patientName,
    this.patientAge,
    this.instructions,
    this.notes,
  });

  final String? number;
  final DateTime? date;
  final String? doctorName;
  final String? patientName;
  final String? patientAge;
  final String? instructions;
  final String? notes;

  bool get hasStructuredData =>
      (number != null && number!.isNotEmpty) ||
      date != null ||
      (doctorName != null && doctorName!.isNotEmpty) ||
      (patientName != null && patientName!.isNotEmpty);

  bool get hasAnyData => hasStructuredData || (notes != null && notes!.isNotEmpty);

  factory PrescriptionInfo.fromOrderJson(Map<String, dynamic> json) {
    DateTime? date;
    final rawDate =
        json['prescriptionDate'] ?? json['prescription_date'];
    if (rawDate != null) {
      date = DateTime.tryParse(rawDate.toString());
    }

    return PrescriptionInfo(
      number: json['prescriptionNumber'] as String? ??
          json['prescription_number'] as String?,
      date: date,
      doctorName:
          json['doctorName'] as String? ?? json['doctor_name'] as String?,
      patientName:
          json['patientName'] as String? ?? json['patient_name'] as String?,
      patientAge:
          json['patientAge'] as String? ?? json['patient_age'] as String?,
      instructions: json['prescriptionInstructions'] as String? ??
          json['prescription_instructions'] as String?,
      notes: json['prescriptionNotes'] as String? ??
          json['prescription_notes'] as String?,
    );
  }

  Map<String, dynamic> toApiJson() {
    final map = <String, dynamic>{};
    if (number != null && number!.trim().isNotEmpty) {
      map['prescription_number'] = number!.trim();
    }
    if (date != null) {
      map['prescription_date'] =
          DateFormat('yyyy-MM-dd').format(date!);
    }
    if (doctorName != null && doctorName!.trim().isNotEmpty) {
      map['doctor_name'] = doctorName!.trim();
    }
    if (patientName != null && patientName!.trim().isNotEmpty) {
      map['patient_name'] = patientName!.trim();
    }
    if (patientAge != null && patientAge!.trim().isNotEmpty) {
      map['patient_age'] = patientAge!.trim();
    }
    if (instructions != null && instructions!.trim().isNotEmpty) {
      map['prescription_instructions'] = instructions!.trim();
    }
    if (notes != null && notes!.trim().isNotEmpty) {
      map['notes'] = notes!.trim();
    }
    return map;
  }

  /// Validasi sebelum submit (order dengan resep / obat resep).
  String? validateRequired() {
    final missing = <String>[];
    if (number == null || number!.trim().isEmpty) {
      missing.add('nomor resep');
    }
    if (date == null) missing.add('tanggal resep');
    if (doctorName == null || doctorName!.trim().isEmpty) {
      missing.add('nama dokter');
    }
    if (patientName == null || patientName!.trim().isEmpty) {
      missing.add('nama pasien');
    }
    if (missing.isEmpty) return null;
    return 'Lengkapi: ${missing.join(', ')}';
  }

  List<({String label, String value})> displayRows() {
    final fmt = DateFormat('dd MMM yyyy', 'id_ID');
    final rows = <({String label, String value})>[];
    if (number != null && number!.isNotEmpty) {
      rows.add((label: 'No. resep', value: number!));
    }
    if (date != null) {
      rows.add((label: 'Tanggal', value: fmt.format(date!.toLocal())));
    }
    if (doctorName != null && doctorName!.isNotEmpty) {
      rows.add((label: 'Dokter', value: doctorName!));
    }
    if (patientName != null && patientName!.isNotEmpty) {
      var pasien = patientName!;
      if (patientAge != null && patientAge!.isNotEmpty) {
        pasien = '$pasien ($patientAge)';
      }
      rows.add((label: 'Pasien', value: pasien));
    } else if (patientAge != null && patientAge!.isNotEmpty) {
      rows.add((label: 'Umur pasien', value: patientAge!));
    }
    if (instructions != null && instructions!.isNotEmpty) {
      rows.add((label: 'Petunjuk / dosis', value: instructions!));
    }
    if (notes != null && notes!.isNotEmpty) {
      rows.add((label: 'Catatan', value: notes!));
    }
    return rows;
  }
}
