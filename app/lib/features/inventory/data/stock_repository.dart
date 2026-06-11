import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_result.dart';
import '../domain/entities/stock_item.dart';
import '../domain/entities/stock_movement.dart';

class StockRepository {
  StockRepository(this._dio);

  final Dio _dio;

  Future<PaginatedResult<StockItem>> getStocks({
    String? branchId,
    String? search,
    bool lowStock = false,
    int page = 1,
    int limit = 20,
    bool tenantWide = false,
    String? locationCode,
    bool? sellableOnly,
  }) async {
    if (!tenantWide && (branchId == null || branchId.isEmpty)) {
      throw Exception('branch_id wajib untuk stok cabang');
    }
    final response = await _dio.get<Map<String, dynamic>>(
      '/stocks',
      queryParameters: {
        ...?branchId != null && branchId.isNotEmpty
            ? {'branch_id': branchId}
            : null,
        ...?search != null && search.isNotEmpty ? {'search': search} : null,
        ...?lowStock ? {'low_stock': true} : null,
        ...?locationCode != null && locationCode.isNotEmpty
            ? {'location_code': locationCode}
            : null,
        ...?sellableOnly != null ? {'sellable_only': sellableOnly} : null,
        'limit': limit,
        'page': page,
      },
    );

    final api = ApiResponse<List<dynamic>>.fromJson(
      response.data!,
      (d) => d as List<dynamic>,
    );

    if (!api.success || api.data == null) throw Exception(api.message);

    return PaginatedResult(
      items: api.data!
          .map((e) => StockItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: PaginatedMeta.fromJson(api.meta),
    );
  }

  Future<Map<String, dynamic>> getRealtimeStock(
    String medicineId, {
    String? branchId,
    bool sellableOnly = true,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/stocks/realtime/$medicineId',
      queryParameters: {
        ...?branchId != null ? {'branch_id': branchId} : null,
        'sellable_only': sellableOnly,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> updateStock({
    required String stockId,
    int? quantity,
    String? rackPosition,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/stocks/$stockId',
      data: {
        ...?quantity != null ? {'quantity': quantity} : null,
        ...?rackPosition != null ? {'rack_position': rackPosition} : null,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> adjustStock({
    required String medicineId,
    required int quantity,
    String? branchId,
    String? batchId,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/stocks/adjust',
      data: {
        'medicine_id': medicineId,
        'quantity': quantity,
        ...?branchId != null ? {'branch_id': branchId} : null,
        ...?batchId != null ? {'batch_id': batchId} : null,
        ...?notes != null ? {'notes': notes} : null,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> receiveStock({
    required String medicineId,
    required int quantity,
    String? branchId,
    String? batchId,
    String? batchNumber,
    String? expiredDate,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/stocks/receive',
      data: {
        'medicine_id': medicineId,
        'quantity': quantity,
        ...?branchId != null ? {'branch_id': branchId} : null,
        ...?batchId != null ? {'batch_id': batchId} : null,
        ...?batchNumber != null && batchNumber.isNotEmpty
            ? {'batch_number': batchNumber}
            : null,
        ...?expiredDate != null ? {'expired_date': expiredDate} : null,
        ...?notes != null ? {'notes': notes} : null,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> mutateStock({
    required String medicineId,
    required int quantity,
    required String movementType,
    String? branchId,
    String? batchId,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/stocks/mutation',
      data: {
        'medicine_id': medicineId,
        'quantity': quantity,
        'movement_type': movementType,
        ...?branchId != null ? {'branch_id': branchId} : null,
        ...?batchId != null ? {'batch_id': batchId} : null,
        ...?notes != null ? {'notes': notes} : null,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<PaginatedResult<StockMovementRow>> getMovements({
    String? branchId,
    String? medicineId,
    String? movementType,
    String? referenceType,
    String? referenceId,
    String? dateFrom,
    String? dateTo,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/stocks/movements',
      queryParameters: {
        ...?branchId != null ? {'branch_id': branchId} : null,
        ...?medicineId != null ? {'medicine_id': medicineId} : null,
        ...?movementType != null ? {'movement_type': movementType} : null,
        ...?referenceType != null ? {'reference_type': referenceType} : null,
        ...?referenceId != null ? {'reference_id': referenceId} : null,
        ...?dateFrom != null ? {'date_from': dateFrom} : null,
        ...?dateTo != null ? {'date_to': dateTo} : null,
        ...?search != null && search.isNotEmpty ? {'search': search} : null,
        'page': page,
        'limit': limit,
      },
    );

    final api = ApiResponse<List<dynamic>>.fromJson(
      response.data!,
      (d) => d as List<dynamic>,
    );

    if (!api.success || api.data == null) throw Exception(api.message);
    return PaginatedResult(
      items: api.data!
          .map((e) => StockMovementRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: PaginatedMeta.fromJson(api.meta),
    );
  }

  Future<Map<String, dynamic>> replenishEtalase({
    required String medicineId,
    required int quantity,
    String? branchId,
    String? batchId,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/stock-internal-moves/replenish',
      data: {
        'medicine_id': medicineId,
        'quantity': quantity,
        ...?branchId != null ? {'branch_id': branchId} : null,
        ...?batchId != null ? {'batch_id': batchId} : null,
        ...?notes != null ? {'notes': notes} : null,
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

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepository(ref.watch(dioProvider));
});
