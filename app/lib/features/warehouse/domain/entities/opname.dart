import 'package:equatable/equatable.dart';

class StockOpname extends Equatable {
  const StockOpname({
    required this.id,
    required this.opnameNumber,
    required this.status,
    required this.createdAt,
    this.itemCount = 0,
  });

  final String id;
  final String opnameNumber;
  final String status;
  final DateTime createdAt;
  final int itemCount;

  factory StockOpname.fromJson(Map<String, dynamic> json) {
    return StockOpname(
      id: json['id'] as String,
      opnameNumber: json['opnameNumber'] as String? ??
          (json['opname_number'] as String? ?? ''),
      status: json['status'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      itemCount: (json['_count'] as Map<String, dynamic>?)?['items'] as int? ??
          0,
    );
  }

  @override
  List<Object?> get props => [id, status];
}

class StockOpnameItemInput extends Equatable {
  const StockOpnameItemInput({
    required this.medicineId,
    required this.medicineName,
    required this.actualQty,
  });

  final String medicineId;
  final String medicineName;
  final int actualQty;

  Map<String, dynamic> toJson() => {
        'medicine_id': medicineId,
        'actual_qty': actualQty,
      };

  @override
  List<Object?> get props => [medicineId, actualQty];
}

