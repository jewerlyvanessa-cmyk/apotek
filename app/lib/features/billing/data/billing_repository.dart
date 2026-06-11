import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../domain/entities/billing_plan.dart';
import '../domain/entities/renewal_intent.dart';

class BillingRepository {
  BillingRepository(this._dio);

  final Dio _dio;

  Future<List<BillingPlan>> listPlans() async {
    final res = await _dio.get<Map<String, dynamic>>('/billing/plans');
    final api = ApiResponse<List<dynamic>>.fromJson(
      res.data!,
      (d) => d as List<dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!
        .map((e) => BillingPlan.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<RenewalIntent> createRenewalIntent({String? plan}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/billing/renewal-intent',
      data: plan != null && plan.isNotEmpty ? {'plan': plan} : null,
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return RenewalIntent.fromJson(api.data!);
  }
}

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(ref.watch(dioProvider));
});
