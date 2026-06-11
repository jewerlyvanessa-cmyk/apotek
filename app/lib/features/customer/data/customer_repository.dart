import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_result.dart';
import '../domain/entities/customer_transactions.dart';
import '../../order/domain/entities/order.dart';

class CustomerRepository {
  CustomerRepository(this._dio);

  final Dio _dio;

  Future<PaginatedResult<Map<String, dynamic>>> searchCustomers({
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/customers',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final api = ApiResponse<List<dynamic>>.fromJson(res.data!, (d) => d as List<dynamic>);
    if (!api.success || api.data == null) throw Exception(api.message);
    return PaginatedResult(
      items: api.data!.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      meta: PaginatedMeta.fromJson(api.meta),
    );
  }

  Future<Map<String, dynamic>> createCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    final trimmedPhone = phone?.trim();
    final trimmedEmail = email?.trim();
    final trimmedAddress = address?.trim();
    final res = await _dio.post<Map<String, dynamic>>(
      '/customers',
      data: {
        'name': name.trim(),
        'phone': ?(trimmedPhone != null && trimmedPhone.isNotEmpty
            ? trimmedPhone
            : null),
        'email': ?(trimmedEmail != null && trimmedEmail.isNotEmpty
            ? trimmedEmail
            : null),
        'address': ?(trimmedAddress != null && trimmedAddress.isNotEmpty
            ? trimmedAddress
            : null),
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> getCustomer(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/customers/$id');
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<CustomerTransactionsResult> getTransactions({
    required String customerId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/customers/$customerId/transactions',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);

    final payload = api.data!;
    final itemsJson = payload['items'] as List<dynamic>? ?? [];
    return CustomerTransactionsResult(
      customer: Map<String, dynamic>.from(
        payload['customer'] as Map<String, dynamic>? ?? {},
      ),
      summary: CustomerTransactionSummary.fromJson(
        Map<String, dynamic>.from(
          payload['summary'] as Map<String, dynamic>? ?? {},
        ),
      ),
      orders: itemsJson
          .map((e) => OrderSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: api.meta ?? Map<String, dynamic>.from(
        payload['meta'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(dioProvider));
});
