import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/drug_classification.dart';
import '../../../../core/constants/product_type.dart';
import '../../domain/entities/order.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem({
    required String medicineId,
    required String name,
    required double sellPrice,
    required int availableStock,
    String? unit,
    String? rackPosition,
    ProductType productType = ProductType.drug,
    DrugClassification? drugClassification,
    bool requiresPrescription = false,
  }) {
    final idx = state.indexWhere((i) => i.medicineId == medicineId);
    if (idx >= 0) {
      final item = state[idx];
      final maxStock = availableStock > item.availableStock
          ? availableStock
          : item.availableStock;
      if (item.quantity >= maxStock) return;
      state = [
        for (var i = 0; i < state.length; i++)
          if (i == idx)
            item.copyWith(
              quantity: item.quantity + 1,
              availableStock: maxStock,
              rackPosition: rackPosition ?? item.rackPosition,
              productType: productType,
              drugClassification: drugClassification ?? item.drugClassification,
              requiresPrescription:
                  requiresPrescription || item.requiresPrescription,
            )
          else
            state[i],
      ];
    } else {
      state = [
        ...state,
        CartItem(
          medicineId: medicineId,
          name: name,
          sellPrice: sellPrice,
          quantity: 1,
          availableStock: availableStock,
          unit: unit,
          rackPosition: rackPosition,
          productType: productType,
          drugClassification: drugClassification,
          requiresPrescription: requiresPrescription,
        ),
      ];
    }
  }

  void updateQty(String medicineId, int qty) {
    if (qty <= 0) {
      removeItem(medicineId);
      return;
    }
    state = [
      for (final item in state)
        if (item.medicineId == medicineId)
          item.copyWith(quantity: qty.clamp(1, item.availableStock))
        else
          item,
    ];
  }

  void incrementQty(String medicineId) {
    final idx = state.indexWhere((i) => i.medicineId == medicineId);
    if (idx < 0) return;
    final item = state[idx];
    if (item.quantity >= item.availableStock) return;
    updateQty(medicineId, item.quantity + 1);
  }

  void decrementQty(String medicineId) {
    final idx = state.indexWhere((i) => i.medicineId == medicineId);
    if (idx < 0) return;
    updateQty(medicineId, state[idx].quantity - 1);
  }

  void removeItem(String medicineId) {
    state = state.where((i) => i.medicineId != medicineId).toList();
  }

  void clear() => state = [];

  void setItems(List<CartItem> items) => state = List.from(items);

  void updateUsageInstructions(String medicineId, String instructions) {
    state = [
      for (final item in state)
        if (item.medicineId == medicineId)
          item.copyWith(usageInstructions: instructions)
        else
          item,
    ];
  }

  double get total => state.fold(0, (sum, i) => sum + i.subtotal);
  int get itemCount => state.fold(0, (sum, i) => sum + i.quantity);
}

final cartProvider =
    StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());
