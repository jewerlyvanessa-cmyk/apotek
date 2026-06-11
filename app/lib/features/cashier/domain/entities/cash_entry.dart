class CashEntry {
  const CashEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.entryDate,
    this.category,
    this.notes,
    this.createdByName,
    this.createdAt,
  });

  final String id;
  final String type;
  final double amount;
  final String entryDate;
  final String? category;
  final String? notes;
  final String? createdByName;
  final String? createdAt;

  bool get isIn => type == 'CASH_IN';

  factory CashEntry.fromJson(Map<String, dynamic> json) {
    final createdBy = json['createdBy'] as Map<String, dynamic>?;
    final entryRaw = json['entryDate']?.toString() ?? json['entry_date']?.toString() ?? '';
    return CashEntry(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      entryDate: entryRaw.length >= 10 ? entryRaw.substring(0, 10) : entryRaw,
      category: json['category']?.toString(),
      notes: json['notes']?.toString(),
      createdByName: createdBy?['fullName']?.toString() ?? createdBy?['full_name']?.toString(),
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString(),
    );
  }
}

class CashLedgerSummary {
  const CashLedgerSummary({
    required this.salesTotal,
    required this.salesOrders,
    required this.cashIn,
    required this.cashOut,
    required this.netManual,
    required this.netTotal,
  });

  final double salesTotal;
  final int salesOrders;
  final double cashIn;
  final double cashOut;
  final double netManual;
  final double netTotal;

  factory CashLedgerSummary.fromJson(Map<String, dynamic> json) {
    return CashLedgerSummary(
      salesTotal: (json['sales_total'] as num?)?.toDouble() ?? 0,
      salesOrders: (json['sales_orders'] as num?)?.toInt() ?? 0,
      cashIn: (json['cash_in'] as num?)?.toDouble() ?? 0,
      cashOut: (json['cash_out'] as num?)?.toDouble() ?? 0,
      netManual: (json['net_manual'] as num?)?.toDouble() ?? 0,
      netTotal: (json['net_total'] as num?)?.toDouble() ?? 0,
    );
  }
}

String cashEntryTypeLabel(String type) {
  switch (type) {
    case 'CASH_IN':
      return 'Uang masuk';
    case 'CASH_OUT':
      return 'Uang keluar';
    default:
      return type;
  }
}

const cashInCategories = [
  'Modal awal',
  'Setoran',
  'Pengembalian',
  'Lainnya',
];

const cashOutCategories = [
  'Operasional',
  'Gaji',
  'Pembelian',
  'Lainnya',
];
