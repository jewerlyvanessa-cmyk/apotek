import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../domain/entities/opname.dart';

class WarehouseRepository {
  WarehouseRepository(this._dio);

  final Dio _dio;

  Future<StockOpname> createOpname({String? branchId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/stock-opnames',
      data: {
        ...?branchId != null ? {'branch_id': branchId} : null,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return StockOpname.fromJson(api.data!);
  }

  Future<List<StockOpname>> listOpnames({String? branchId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/stock-opnames',
      queryParameters: {
        ...?branchId != null ? {'branch_id': branchId} : null,
        'limit': 50,
      },
    );
    final api = ApiResponse<List<dynamic>>.fromJson(
      response.data!,
      (d) => d as List<dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!
        .map((e) => StockOpname.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertOpnameItems({
    required String opnameId,
    required List<StockOpnameItemInput> items,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/stock-opnames/$opnameId/items',
      data: {'items': items.map((e) => e.toJson()).toList()},
    );
    final api = ApiResponse<dynamic>.fromJson(response.data!, null);
    if (!api.success) throw Exception(api.message);
  }

  Future<void> submitOpname(String opnameId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/stock-opnames/$opnameId/submit',
    );
    final api = ApiResponse<dynamic>.fromJson(response.data!, null);
    if (!api.success) throw Exception(api.message);
  }
}

final warehouseRepositoryProvider = Provider<WarehouseRepository>((ref) {
  return WarehouseRepository(ref.watch(dioProvider));
});

