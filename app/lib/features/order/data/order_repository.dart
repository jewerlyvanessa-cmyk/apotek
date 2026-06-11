import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../domain/entities/order.dart';

class OrderRepository {
  OrderRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> createOrder({
    String? customerId,
    String? customerName,
    String? customerPhone,
    Map<String, dynamic>? prescription,
    bool hasPrescription = false,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/orders',
      data: {
        if (customerId != null && customerId.isNotEmpty) 'customer_id': customerId,
        if (customerName != null && customerName.isNotEmpty)
          'customer_name': customerName,
        if (customerPhone != null && customerPhone.isNotEmpty)
          'customer_phone': customerPhone,
        if (prescription != null && prescription.isNotEmpty)
          'prescription': prescription,
        if (hasPrescription) 'has_prescription': true,
        'items': items,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<List<OrderSummary>> getOrders({
    String? status,
    String? branchId,
    String? dateFrom,
    String? dateTo,
    String? search,
    bool mine = false,
    bool reviewedMine = false,
    int limit = 50,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/orders',
      queryParameters: {
        ...?status != null ? {'status': status} : null,
        ...?branchId != null ? {'branch_id': branchId} : null,
        ...?dateFrom != null ? {'date_from': dateFrom} : null,
        ...?dateTo != null ? {'date_to': dateTo} : null,
        ...?search != null && search.isNotEmpty ? {'search': search} : null,
        ...?mine ? {'mine': true} : null,
        ...?reviewedMine ? {'reviewed_mine': true} : null,
        'limit': limit,
      },
    );
    final api = ApiResponse<List<dynamic>>.fromJson(
      response.data!,
      (d) => d as List<dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!
        .map((e) => OrderSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OrderSummary> getOrder(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/orders/$id');
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return OrderSummary.fromJson(api.data!);
  }

  Future<Map<String, dynamic>> updateOrder({
    required String orderId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/orders/$orderId',
      data: {
        if (customerId != null && customerId.isNotEmpty) 'customer_id': customerId,
        if (customerName != null && customerName.isNotEmpty)
          'customer_name': customerName,
        if (customerPhone != null && customerPhone.isNotEmpty)
          'customer_phone': customerPhone,
        'items': items,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> approvePharmacy({
    required String orderId,
    String? pharmacistNotes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/orders/$orderId/approve-pharmacy',
      data: {
        if (pharmacistNotes != null && pharmacistNotes.isNotEmpty)
          'pharmacist_notes': pharmacistNotes,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> refundOrder(
    String orderId, {
    String? reason,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/orders/$orderId/refund',
      data: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<void> cancelOrder(String id) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/orders/$id/cancel',
    );
    final api = ApiResponse<dynamic>.fromJson(response.data!, null);
    if (!api.success) throw Exception(api.message);
  }

  Future<Map<String, dynamic>> payOrder({
    required String orderId,
    required String paymentMethod,
    required double amount,
    double? amountReceived,
    String? proofImageUrl,
    List<Map<String, dynamic>>? splits,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/payments',
      data: splits != null && splits.isNotEmpty
          ? {
              'order_id': orderId,
              'splits': splits,
            }
          : {
              'order_id': orderId,
              'payment_method': paymentMethod,
              'amount': amount.round(),
              if (amountReceived != null)
                'amount_received': amountReceived.round(),
              if (proofImageUrl != null && proofImageUrl.isNotEmpty)
                'proof_image_url': proofImageUrl,
            },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(dioProvider));
});
