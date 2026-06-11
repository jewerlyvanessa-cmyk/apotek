import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_result.dart';
import '../domain/entities/cash_entry.dart';

class CashEntryRepository {
  CashEntryRepository(this._dio);

  final Dio _dio;

  Future<PaginatedResult<CashEntry>> list({
    required String branchId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/cash-entries',
      queryParameters: {
        'branch_id': branchId,
        ...?dateFrom != null ? {'date_from': dateFrom} : null,
        ...?dateTo != null ? {'date_to': dateTo} : null,
        'limit': limit,
        'page': page,
      },
    );
    final api = ApiResponse<List<dynamic>>.fromJson(
      res.data!,
      (d) => d as List<dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return PaginatedResult(
      items: api.data!
          .map((e) => CashEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: PaginatedMeta.fromJson(api.meta),
    );
  }

  Future<CashLedgerSummary> summary({
    required String branchId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/cash-entries/summary',
      queryParameters: {
        'branch_id': branchId,
        ...?dateFrom != null ? {'date_from': dateFrom} : null,
        ...?dateTo != null ? {'date_to': dateTo} : null,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return CashLedgerSummary.fromJson(api.data!);
  }

  Future<CashEntry> create({
    required String type,
    required double amount,
    String? category,
    String? notes,
    String? entryDate,
    String? branchId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/cash-entries',
      data: {
        'type': type,
        'amount': amount,
        ...?category != null && category.isNotEmpty ? {'category': category} : null,
        ...?notes != null && notes.isNotEmpty ? {'notes': notes} : null,
        ...?entryDate != null ? {'entry_date': entryDate} : null,
        ...?branchId != null ? {'branch_id': branchId} : null,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return CashEntry.fromJson(api.data!);
  }

  Future<void> delete(String id) async {
    final res = await _dio.delete<Map<String, dynamic>>('/cash-entries/$id');
    final api = ApiResponse<dynamic>.fromJson(res.data!, (d) => d);
    if (!api.success) throw Exception(api.message);
  }
}

final cashEntryRepositoryProvider = Provider<CashEntryRepository>((ref) {
  return CashEntryRepository(ref.watch(dioProvider));
});
