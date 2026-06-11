import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';

class SetupRepository {
  SetupRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getStatus() async {
    final res = await _dio.get<Map<String, dynamic>>('/setup/status');
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> getDatabaseConfig() async {
    final res = await _dio.get<Map<String, dynamic>>('/setup/database');
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> testConnection(Map<String, dynamic> body) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/setup/database/test',
      data: body,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> createDatabase(Map<String, dynamic> body) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/setup/database/create',
      data: body,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> runMigrate(Map<String, dynamic> body) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/setup/database/migrate',
      data: body,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> applyConfig(Map<String, dynamic> body) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/setup/database/apply',
      data: body,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }
}

final setupRepositoryProvider = Provider<SetupRepository>((ref) {
  return SetupRepository(ref.watch(dioProvider));
});
