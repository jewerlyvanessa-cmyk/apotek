import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';

class BackupRepository {
  BackupRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> backupBranch({String? branchId}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/backup/branch',
      queryParameters: {
        if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> backupTenant() async {
    final res = await _dio.get<Map<String, dynamic>>('/backup/tenant');
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }
}

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepository(ref.watch(dioProvider));
});
