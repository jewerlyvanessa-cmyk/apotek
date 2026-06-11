import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../domain/entities/report_models.dart';

class ReportsRepository {
  ReportsRepository(this._dio);

  final Dio _dio;

  Future<DashboardSummary> getDashboard({
    String? dateFrom,
    String? dateTo,
    String? branchId,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/reports/dashboard',
      queryParameters: {
        ...?dateFrom != null ? {'date_from': dateFrom} : null,
        ...?dateTo != null ? {'date_to': dateTo} : null,
        ...?branchId != null ? {'branch_id': branchId} : null,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return DashboardSummary.fromJson(api.data!);
  }

  Future<List<TopMedicineRow>> topMedicines({
    String? dateFrom,
    String? dateTo,
    String? branchId,
    int limit = 10,
    String orderBy = 'qty',
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/reports/top-medicines',
      queryParameters: {
        ...?dateFrom != null ? {'date_from': dateFrom} : null,
        ...?dateTo != null ? {'date_to': dateTo} : null,
        ...?branchId != null ? {'branch_id': branchId} : null,
        'limit': limit,
        'order_by': orderBy,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    final items = (api.data?['items'] as List? ?? const []);
    return items
        .map((e) => TopMedicineRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<LowStockRow>> lowStock({String? branchId}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/reports/low-stock',
      queryParameters: {
        ...?branchId != null ? {'branch_id': branchId} : null,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    final items = (api.data?['items'] as List? ?? const []);
    return items
        .map((e) => LowStockRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SalesReport> sales({
    String? dateFrom,
    String? dateTo,
    String? branchId,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/reports/sales',
      queryParameters: {
        ...?dateFrom != null ? {'date_from': dateFrom} : null,
        ...?dateTo != null ? {'date_to': dateTo} : null,
        ...?branchId != null ? {'branch_id': branchId} : null,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return SalesReport.fromJson(api.data!);
  }

  Future<ProfitLossReport> profitLoss({
    String? dateFrom,
    String? dateTo,
    String? branchId,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/reports/profit-loss',
      queryParameters: {
        ...?dateFrom != null ? {'date_from': dateFrom} : null,
        ...?dateTo != null ? {'date_to': dateTo} : null,
        ...?branchId != null ? {'branch_id': branchId} : null,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return ProfitLossReport.fromJson(api.data!);
  }

  Future<Uint8List> downloadReport(
    String path, {
    String? dateFrom,
    String? dateTo,
    String? branchId,
  }) async {
    final res = await _dio.get<List<int>>(
      path,
      queryParameters: {
        ...?dateFrom != null ? {'date_from': dateFrom} : null,
        ...?dateTo != null ? {'date_to': dateTo} : null,
        ...?branchId != null ? {'branch_id': branchId} : null,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? []);
  }

  Future<List<ExpiredRow>> expired({String? branchId}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/reports/expired',
      queryParameters: {
        ...?branchId != null ? {'branch_id': branchId} : null,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    final items = (api.data?['items'] as List? ?? const []);
    return items
        .map((e) => ExpiredRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(dioProvider));
});

