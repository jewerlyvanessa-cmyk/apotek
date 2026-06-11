import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/order_repository.dart';
import '../../domain/entities/order.dart';

final waitingOrdersProvider =
    FutureProvider.autoDispose<List<OrderSummary>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  final branchId = ref.watch(authProvider).user?.branchId;
  final results = await Future.wait([
    repo.getOrders(status: 'WAITING_PAYMENT', branchId: branchId),
    repo.getOrders(status: 'WAITING_QRIS', branchId: branchId),
  ]);
  final seen = <String>{};
  final merged = <OrderSummary>[];
  for (final list in results) {
    for (final o in list) {
      if (seen.add(o.id)) merged.add(o);
    }
  }
  merged.sort((a, b) {
    final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bt.compareTo(at);
  });
  return merged;
});

/// Order hari ini yang dibuat oleh user login (staff / asisten).
final staffTodayOrdersProvider =
    FutureProvider.autoDispose<List<OrderSummary>>((ref) async {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  final iso = day.toIso8601String();
  final branchId = ref.watch(authProvider).user?.branchId;
  return ref.watch(orderRepositoryProvider).getOrders(
        dateFrom: iso,
        dateTo: iso,
        mine: true,
        branchId: branchId,
        limit: 30,
      );
});

/// Order menunggu telaah apoteker di cabang login.
final pendingPharmacyOrdersHomeProvider =
    FutureProvider.autoDispose<List<OrderSummary>>((ref) async {
  final branchId = ref.watch(authProvider).user?.branchId;
  return ref.watch(orderRepositoryProvider).getOrders(
        status: 'PENDING_PHARMACY',
        branchId: branchId,
        limit: 30,
      );
});

/// Telaah apoteker hari ini oleh user login.
final pharmacistTodayReviewsProvider =
    FutureProvider.autoDispose<List<OrderSummary>>((ref) async {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  final iso = day.toIso8601String();
  final branchId = ref.watch(authProvider).user?.branchId;
  return ref.watch(orderRepositoryProvider).getOrders(
        dateFrom: iso,
        dateTo: iso,
        reviewedMine: true,
        branchId: branchId,
        limit: 30,
      );
});

final orderDetailProvider =
    FutureProvider.autoDispose.family<OrderSummary, String>((ref, id) async {
  return ref.watch(orderRepositoryProvider).getOrder(id);
});
