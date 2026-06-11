import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_result.dart';

class PlatformRepository {
  PlatformRepository(this._dio);

  final Dio _dio;

  Future<PaginatedResult<Map<String, dynamic>>> listTenants({
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/platform/tenants',
      queryParameters: {
        'page': page,
        'limit': limit,
        ...?search != null && search.isNotEmpty ? {'search': search} : null,
      },
    );
    final api = ApiResponse<List<dynamic>>.fromJson(res.data!, (d) => d as List<dynamic>);
    if (!api.success || api.data == null) throw Exception(api.message);
    return PaginatedResult(
      items: api.data!.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      meta: PaginatedMeta.fromJson(api.meta),
    );
  }

  Future<Map<String, dynamic>> getTenant(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/platform/tenants/$id');
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> createTenant({
    required String name,
    required String code,
    String? phone,
    String? email,
    String? address,
    String? subscriptionPlan,
    bool createCentralWarehouse = true,
    String? centralBranchName,
    String? centralBranchCode,
    required String ownerFullName,
    required String ownerEmail,
    required String ownerPassword,
    String? ownerPhone,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/platform/tenants',
      data: {
        'name': name,
        'code': code,
        ...?phone != null && phone.isNotEmpty ? {'phone': phone} : null,
        ...?email != null && email.isNotEmpty ? {'email': email} : null,
        ...?address != null && address.isNotEmpty ? {'address': address} : null,
        ...?subscriptionPlan != null && subscriptionPlan.isNotEmpty
            ? {'subscription_plan': subscriptionPlan}
            : null,
        'create_central_warehouse': createCentralWarehouse,
        ...?centralBranchName != null && centralBranchName.isNotEmpty
            ? {'central_branch_name': centralBranchName}
            : null,
        ...?centralBranchCode != null && centralBranchCode.isNotEmpty
            ? {'central_branch_code': centralBranchCode}
            : null,
        'owner': {
          'full_name': ownerFullName,
          'email': ownerEmail,
          'password': ownerPassword,
          ...?ownerPhone != null && ownerPhone.isNotEmpty
              ? {'phone': ownerPhone}
              : null,
        },
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> provisionOwner({
    required String tenantId,
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/platform/tenants/$tenantId/owner',
      data: {
        'full_name': fullName,
        'email': email,
        'password': password,
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

  Future<Map<String, dynamic>> deleteTenant(String id) async {
    final res = await _dio.delete<Map<String, dynamic>>('/platform/tenants/$id');
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return {
      ...api.data!,
      if (api.message.isNotEmpty) '_apiMessage': api.message,
    };
  }

  Future<Map<String, dynamic>> deleteBranch({
    required String tenantId,
    required String branchId,
  }) async {
    final res = await _dio.delete<Map<String, dynamic>>(
      '/platform/tenants/$tenantId/branches/$branchId',
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> updateTenant({
    required String id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? subscriptionPlan,
    bool? isActive,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/platform/tenants/$id',
      data: {
        ...?name != null ? {'name': name} : null,
        ...?phone != null ? {'phone': phone} : null,
        ...?email != null ? {'email': email} : null,
        ...?address != null ? {'address': address} : null,
        ...?subscriptionPlan != null ? {'subscription_plan': subscriptionPlan} : null,
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

  Future<List<Map<String, dynamic>>> listBranches({
    required String tenantId,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/platform/branches',
      queryParameters: {'tenant_id': tenantId, 'limit': 100},
    );
    final api = ApiResponse<List<dynamic>>.fromJson(res.data!, (d) => d as List<dynamic>);
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createBranch({
    required String tenantId,
    required String name,
    String? code,
    String? address,
    String? phone,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/platform/tenants/$tenantId/branches',
      data: {
        'name': name,
        ...?code != null && code.isNotEmpty ? {'code': code} : null,
        ...?address != null && address.isNotEmpty ? {'address': address} : null,
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

  Future<Map<String, dynamic>> listLicensePlans() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/platform/licenses/plans',
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> extendTenantSubscription({
    required String tenantId,
    String? plan,
    int? extendDays,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/platform/tenants/$tenantId/subscription',
      data: {
        'plan': ?plan,
        'extend_days': ?extendDays,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> generateLicense({
    required String customer,
    String type = 'perpetual',
    String? plan,
    String? tenantId,
    String? tenantCode,
    int? maxBranches,
    int? days,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/platform/licenses/generate',
      data: {
        'customer': customer,
        'type': type,
        'plan': ?plan,
        if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
        'tenant_code': ?tenantCode,
        'max_branches': ?maxBranches,
        'days': ?days,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> backupTenant(String tenantId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/platform/backup/tenant/$tenantId',
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> backupBranch({
    required String tenantId,
    required String branchId,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/platform/backup/branch/$branchId',
      queryParameters: {'tenant_id': tenantId},
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  Future<Map<String, dynamic>> updateBranch({
    required String tenantId,
    required String branchId,
    String? name,
    String? code,
    String? address,
    String? phone,
    bool? isActive,
    bool? isCentralWarehouse,
  }) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/platform/tenants/$tenantId/branches/$branchId',
      data: {
        ...?name != null ? {'name': name} : null,
        ...?code != null ? {'code': code} : null,
        ...?address != null ? {'address': address} : null,
        ...?phone != null ? {'phone': phone} : null,
        ...?isActive != null ? {'is_active': isActive} : null,
        ...?isCentralWarehouse != null
            ? {'is_central_warehouse': isCentralWarehouse}
            : null,
      },
    );
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      res.data!,
      (d) => d as Map<String, dynamic>,
    );
    if (!api.success || api.data == null) throw Exception(api.message);
    return api.data!;
  }
}

final platformRepositoryProvider = Provider<PlatformRepository>((ref) {
  return PlatformRepository(ref.watch(dioProvider));
});
