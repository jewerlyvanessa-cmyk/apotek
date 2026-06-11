import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../domain/entities/license_status.dart';

class LicenseRepository {
  LicenseRepository(this._dio);

  final Dio _dio;

  Future<LicenseStatus> getStatus() async {
    final res = await _dio.get<Map<String, dynamic>>('/license/status');
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return LicenseStatus.fromJson(api.data!);
  }

  Future<LicenseStatus> getMyStatus() async {
    final res = await _dio.get<Map<String, dynamic>>('/license/me');
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return LicenseStatus.fromJson(api.data!);
  }

  Future<void> activateLicense(String licenseKey) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/license/activate',
      data: {'license_key': licenseKey.trim()},
      options: Options(
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final body = res.data;
    if (body is! Map<String, dynamic>) {
      throw Exception('Gagal mengaktifkan lisensi');
    }
    final api = ApiResponse<dynamic>.fromJson(body, null);
    if (!api.success) throw Exception(api.message);
  }
}

final licenseRepositoryProvider = Provider<LicenseRepository>((ref) {
  return LicenseRepository(ref.watch(dioProvider));
});
