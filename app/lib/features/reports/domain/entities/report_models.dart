class DashboardSummary {
  const DashboardSummary({
    required this.todaySales,
    required this.todayOrders,
    required this.lowStock,
  });

  final double todaySales;
  final int todayOrders;
  final int lowStock;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      todaySales: (json['today_sales'] as num?)?.toDouble() ?? 0,
      todayOrders: (json['today_orders'] as num?)?.toInt() ?? 0,
      lowStock: (json['low_stock'] as num?)?.toInt() ?? 0,
    );
  }
}

class TopMedicineRow {
  const TopMedicineRow({
    required this.medicineId,
    required this.medicineName,
    required this.unit,
    required this.qty,
    required this.subtotal,
  });

  final String medicineId;
  final String medicineName;
  final String? unit;
  final int qty;
  final double subtotal;

  factory TopMedicineRow.fromJson(Map<String, dynamic> json) {
    return TopMedicineRow(
      medicineId: json['medicine_id'] as String? ?? '',
      medicineName: json['medicine_name'] as String? ?? '',
      unit: json['unit'] as String?,
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    );
  }
}

class LowStockRow {
  const LowStockRow({
    required this.branchId,
    required this.medicineId,
    required this.medicineName,
    required this.minStock,
    required this.quantity,
    required this.reservedQuantity,
    required this.availableQuantity,
  });

  final String branchId;
  final String medicineId;
  final String medicineName;
  final int minStock;
  final int quantity;
  final int reservedQuantity;
  final int availableQuantity;

  factory LowStockRow.fromJson(Map<String, dynamic> json) {
    return LowStockRow(
      branchId: json['branch_id'] as String? ?? '',
      medicineId: json['medicine_id'] as String? ?? '',
      medicineName: json['medicine_name'] as String? ?? '',
      minStock: (json['min_stock'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      reservedQuantity: (json['reserved_quantity'] as num?)?.toInt() ?? 0,
      availableQuantity: (json['available_quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

class SalesTotals {
  const SalesTotals({
    required this.orders,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
  });

  final int orders;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;

  factory SalesTotals.fromJson(Map<String, dynamic> json) {
    return SalesTotals(
      orders: (json['orders'] as num?)?.toInt() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SalesOrderRow {
  const SalesOrderRow({
    required this.id,
    required this.orderNumber,
    required this.branchId,
    required this.total,
    required this.paidAt,
  });

  final String id;
  final String orderNumber;
  final String branchId;
  final double total;
  final DateTime? paidAt;

  factory SalesOrderRow.fromJson(Map<String, dynamic> json) {
    return SalesOrderRow(
      id: json['id'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ??
          json['order_number'] as String? ??
          '',
      branchId: json['branchId'] as String? ??
          json['branch_id'] as String? ??
          '',
      total: (json['total'] as num?)?.toDouble() ?? 0,
      paidAt: () {
        final raw = json['paidAt'] ?? json['paid_at'];
        if (raw == null) return null;
        return DateTime.tryParse(raw.toString());
      }(),
    );
  }
}

class SalesReport {
  const SalesReport({
    required this.branchId,
    required this.totals,
    required this.orders,
  });

  final String? branchId;
  final SalesTotals totals;
  final List<SalesOrderRow> orders;

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    final items = (json['orders'] as List? ?? const []);
    return SalesReport(
      branchId: json['branch_id'] as String?,
      totals: SalesTotals.fromJson(json['totals'] as Map<String, dynamic>? ?? const {}),
      orders: items.map((e) => SalesOrderRow.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class ProfitLossTotals {
  const ProfitLossTotals({
    required this.revenue,
    required this.cost,
    required this.grossProfit,
    required this.marginPercent,
  });

  final double revenue;
  final double cost;
  final double grossProfit;
  final double marginPercent;

  factory ProfitLossTotals.fromJson(Map<String, dynamic> json) {
    return ProfitLossTotals(
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      grossProfit: (json['gross_profit'] as num?)?.toDouble() ?? 0,
      marginPercent: (json['margin_percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ProfitLossRow {
  const ProfitLossRow({
    required this.medicineId,
    required this.medicineName,
    required this.unit,
    required this.qty,
    required this.revenue,
    required this.cost,
    required this.grossProfit,
  });

  final String medicineId;
  final String medicineName;
  final String? unit;
  final int qty;
  final double revenue;
  final double cost;
  final double grossProfit;

  factory ProfitLossRow.fromJson(Map<String, dynamic> json) {
    return ProfitLossRow(
      medicineId: json['medicine_id'] as String? ?? '',
      medicineName: json['medicine_name'] as String? ?? '',
      unit: json['unit'] as String?,
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      grossProfit: (json['gross_profit'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ProfitLossReport {
  const ProfitLossReport({
    required this.totals,
    required this.items,
  });

  final ProfitLossTotals totals;
  final List<ProfitLossRow> items;

  factory ProfitLossReport.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? const []);
    return ProfitLossReport(
      totals: ProfitLossTotals.fromJson(
        json['totals'] as Map<String, dynamic>? ?? const {},
      ),
      items: items
          .map((e) => ProfitLossRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ExpiredRow {
  const ExpiredRow({
    required this.branchId,
    required this.medicineId,
    required this.medicineName,
    required this.batchId,
    required this.batchNumber,
    required this.expiredDate,
    required this.quantity,
  });

  final String branchId;
  final String medicineId;
  final String medicineName;
  final String batchId;
  final String batchNumber;
  final String expiredDate;
  final int quantity;

  factory ExpiredRow.fromJson(Map<String, dynamic> json) {
    return ExpiredRow(
      branchId: json['branch_id'] as String? ?? '',
      medicineId: json['medicine_id'] as String? ?? '',
      medicineName: json['medicine_name'] as String? ?? '',
      batchId: json['batch_id'] as String? ?? '',
      batchNumber: json['batch_number'] as String? ?? '',
      expiredDate: json['expired_date'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

