import 'package:equatable/equatable.dart';

class StockItem extends Equatable {
  const StockItem({
    required this.id,
    required this.medicineId,
    required this.branchId,
    required this.medicineName,
    required this.quantity,
    required this.reservedQuantity,
    required this.availableQuantity,
    this.barcode,
    this.unit,
    this.minStock = 0,
    this.batchNumber,
    this.expiredDate,
    this.batchId,
    this.branchName,
    this.rackPosition,
    this.locationCode,
    this.locationName,
  });

  final String id;
  final String medicineId;
  final String branchId;
  final String medicineName;
  final String? barcode;
  final String? unit;
  final int quantity;
  final int reservedQuantity;
  final int availableQuantity;
  final int minStock;
  final String? batchNumber;
  final DateTime? expiredDate;
  final String? batchId;
  final String? branchName;
  final String? rackPosition;
  final String? locationCode;
  final String? locationName;

  StockStatus get status {
    if (availableQuantity <= 0) return StockStatus.outOfStock;
    if (availableQuantity <= minStock) return StockStatus.low;
    return StockStatus.ok;
  }

  factory StockItem.fromJson(Map<String, dynamic> json) {
    final medicine = json['medicine'] as Map<String, dynamic>?;
    final batch = json['batch'] as Map<String, dynamic>?;
    final branch = json['branch'] as Map<String, dynamic>?;
    final qty = json['quantity'] as int? ?? 0;
    final reserved = json['reservedQuantity'] as int? ??
        json['reserved_quantity'] as int? ??
        0;
    final available = json['available_quantity'] as int? ??
        json['availableQuantity'] as int? ??
        (qty - reserved);

    return StockItem(
      id: json['id'] as String,
      medicineId: json['medicineId'] as String? ?? json['medicine_id'] as String,
      branchId: json['branchId'] as String? ?? json['branch_id'] as String,
      medicineName: medicine?['name'] as String? ?? '',
      barcode: medicine?['barcode'] as String?,
      unit: medicine?['unit'] as String?,
      quantity: qty,
      reservedQuantity: reserved,
      availableQuantity: available,
      minStock: medicine?['minStock'] as int? ?? medicine?['min_stock'] as int? ?? 0,
      batchNumber: batch?['batchNumber'] as String? ?? batch?['batch_number'] as String?,
      expiredDate: batch?['expiredDate'] != null
          ? DateTime.tryParse(batch!['expiredDate'].toString())
          : batch?['expired_date'] != null
              ? DateTime.tryParse(batch!['expired_date'].toString())
              : null,
      batchId: json['batchId'] as String? ?? json['batch_id'] as String?,
      branchName: branch?['name'] as String?,
      rackPosition: json['rackPosition'] as String? ??
          json['rack_position'] as String?,
      locationCode: json['location_code'] as String? ??
          json['locationCode'] as String?,
      locationName: json['location_name'] as String? ??
          json['locationName'] as String?,
    );
  }

  StockItem copyWithRealtime({
    required int quantity,
    required int reservedQuantity,
    required int availableQuantity,
  }) {
    return StockItem(
      id: id,
      medicineId: medicineId,
      branchId: branchId,
      medicineName: medicineName,
      barcode: barcode,
      unit: unit,
      quantity: quantity,
      reservedQuantity: reservedQuantity,
      availableQuantity: availableQuantity,
      minStock: minStock,
      batchNumber: batchNumber,
      expiredDate: expiredDate,
      batchId: batchId,
      branchName: branchName,
      rackPosition: rackPosition,
      locationCode: locationCode,
      locationName: locationName,
    );
  }

  @override
  List<Object?> get props => [id, medicineId, branchId, availableQuantity];
}

enum StockStatus { ok, low, outOfStock }
