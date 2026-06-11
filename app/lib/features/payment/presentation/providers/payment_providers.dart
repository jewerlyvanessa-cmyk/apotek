import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/payment_repository.dart';
import '../../domain/entities/payment_summary.dart';

final cashierTodayPaymentsProvider =
    FutureProvider.autoDispose<List<PaymentSummary>>((ref) async {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  final iso = day.toIso8601String();
  final result = await ref.watch(paymentRepositoryProvider).getPayments(
        dateFrom: iso,
        dateTo: iso,
        mine: true,
        limit: 50,
      );
  return result.items;
});

final paymentDetailProvider =
    FutureProvider.autoDispose.family<PaymentSummary, String>((ref, id) async {
  return ref.watch(paymentRepositoryProvider).getPayment(id);
});
