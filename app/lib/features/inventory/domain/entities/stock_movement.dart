class StockMovementRow {
  const StockMovementRow({
    required this.id,
    required this.createdAt,
    required this.branchId,
    required this.medicineId,
    required this.medicineName,
    required this.unit,
    required this.batchId,
    required this.batchNumber,
    required this.expiredDate,
    required this.movementType,
    required this.quantity,
    required this.referenceType,
    required this.referenceId,
    required this.notes,
    required this.createdByName,
    this.branchName,
  });

  final String id;
  final DateTime? createdAt;
  final String branchId;
  final String medicineId;
  final String? medicineName;
  final String? unit;
  final String? batchId;
  final String? batchNumber;
  final DateTime? expiredDate;
  final String movementType;
  final int quantity;
  final String? referenceType;
  final String? referenceId;
  final String? notes;
  final String? createdByName;
  final String? branchName;

  factory StockMovementRow.fromJson(Map<String, dynamic> json) {
    return StockMovementRow(
      id: json['id'] as String? ?? '',
      createdAt:
          json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      branchId: json['branch_id'] as String? ?? '',
      medicineId: json['medicine_id'] as String? ?? '',
      medicineName: json['medicine_name'] as String?,
      unit: json['unit'] as String?,
      batchId: json['batch_id'] as String?,
      batchNumber: json['batch_number'] as String?,
      expiredDate: json['expired_date'] != null
          ? DateTime.tryParse(json['expired_date'] as String)
          : null,
      movementType: json['movement_type'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      notes: json['notes'] as String?,
      createdByName: (json['created_by'] as Map?)?['full_name'] as String?,
      branchName: json['branch_name'] as String?,
    );
  }
}

