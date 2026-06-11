import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_result.dart';

class AdminRepository {
  AdminRepository(this._dio);

  final Dio _dio;

  /// Cabang aktif saja. Cabang nonaktif hanya di modul Platform (Super Admin).
  Future<List<Map<String, dynamic>>> listBranches() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/branches',
      queryParameters: {'limit': 100},
    );
    final api = ApiResponse<List<dynamic>>.fromJson(res.data!, (d) => d as List<dynamic>);
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<PaginatedResult<Map<String, dynamic>>> listUsers({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/users',
      queryParameters: {'page': page, 'limit': limit},
    );
    final api = ApiResponse<List<dynamic>>.fromJson(res.data!, (d) => d as List<dynamic>);
    if (!api.success || api.data == null) throw Exception(api.message);
    return PaginatedResult(
      items: api.data!.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      meta: PaginatedMeta.fromJson(api.meta),
    );
  }

  Future<Map<String, dynamic>> createUser({
    required String fullName,
    required String email,
    required String password,
    List<String>? globalRoles,
    List<Map<String, dynamic>>? branchAssignments,
    String? activeRole,
    String? branchId,
    String? phone,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/users',
      data: {
        'full_name': fullName,
        'email': email,
        'password': password,
        if (globalRoles != null && globalRoles.isNotEmpty)
          'global_roles': globalRoles,
        if (branchAssignments != null && branchAssignments.isNotEmpty)
          'branch_assignments': branchAssignments,
        'active_role': ?activeRole,
        ...?branchId != null && branchId.isNotEmpty ? {'branch_id': branchId} : null,
        ...?phone != null && phone.isNotEmpty ? {'phone': phone} : null,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<void> updateUserRole({
    required String userId,
    required List<String> roles,
    String? activeRole,
  }) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/users/$userId/role',
      data: {
        'roles': roles,
        'active_role': ?activeRole,
      },
    );
    final api = ApiResponse<dynamic>.fromJson(res.data!, null);
    if (!api.success) throw Exception(api.message);
  }

  Future<Map<String, dynamic>> updateUser({
    required String userId,
    String? fullName,
    List<String>? globalRoles,
    List<Map<String, dynamic>>? branchAssignments,
    String? branchId,
    String? phone,
    bool? isActive,
  }) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/users/$userId',
      data: {
        ...?fullName != null ? {'full_name': fullName} : null,
        'global_roles': ?globalRoles,
        'branch_assignments': ?branchAssignments,
        ...?branchId != null ? {'branch_id': branchId} : null,
        ...?phone != null ? {'phone': phone} : null,
        ...?isActive != null ? {'is_active': isActive} : null,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> updateBranchStockMode({
    required String branchId,
    required String stockMode,
    String? moveExistingTo,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/branches/$branchId/stock-mode',
      data: {
        'stock_mode': stockMode,
        ...?moveExistingTo != null ? {'move_existing_to': moveExistingTo} : null,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<List<Map<String, dynamic>>> listStockLocations(String branchId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/branches/$branchId/stock-locations',
    );
    final api = ApiResponse<List<dynamic>>.fromJson(
      res.data!,
      (d) => d as List<dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> deleteUser(String userId) async {
    final res = await _dio.delete<Map<String, dynamic>>('/users/$userId');
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<void> resetUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/users/$userId/password',
      data: {'new_password': newPassword},
    );
    final api = ApiResponse<dynamic>.fromJson(res.data!, null);
    if (!api.success) throw Exception(api.message);
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(dioProvider));
});

