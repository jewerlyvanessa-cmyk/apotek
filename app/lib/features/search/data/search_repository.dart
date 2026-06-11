import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';

class GlobalSearchResult {
  const GlobalSearchResult({
    required this.medicines,
    required this.customers,
    required this.orders,
  });

  final List<Map<String, dynamic>> medicines;
  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> orders;

  bool get isEmpty =>
      medicines.isEmpty && customers.isEmpty && orders.isEmpty;
}

class SearchRepository {
  SearchRepository(this._dio);

  final Dio _dio;

  Future<GlobalSearchResult> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      return const GlobalSearchResult(
        medicines: [],
        customers: [],
        orders: [],
      );
    }

    final results = await Future.wait([
      _searchList('/medicines', q, limit: 8),
      _searchList('/customers', q, limit: 8),
      _searchList('/orders', q, limit: 8),
    ]);

    return GlobalSearchResult(
      medicines: results[0],
      customers: results[1],
      orders: results[2],
    );
  }

  Future<List<Map<String, dynamic>>> _searchList(
    String path,
    String query, {
    required int limit,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: {'search': query, 'limit': limit, 'page': 1},
    );
    final api = ApiResponse<List<dynamic>>.fromJson(
      res.data!,
      (d) => d as List<dynamic>,
    );
    if (!api.success || api.data == null) return [];
    return api.data!
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(dioProvider));
});
