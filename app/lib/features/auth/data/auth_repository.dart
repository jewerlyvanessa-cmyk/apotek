import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/entities/auth_user.dart';

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final TokenStorage _storage;

  Future<AuthUser> login({
    required String email,
    required String password,
    String? activeRole,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
        'device_name': 'ApotikFlow App',
        'active_role': ?activeRole,
      },
    );

    return _persistAuthResponse(response.data!);
  }

  Future<AuthUser> switchRole(String role) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/switch-role',
      data: {'role': role},
    );
    return _persistAuthResponse(response.data!);
  }

  Future<AuthUser> switchBranch(
    String branchId, {
    String? role,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/switch-branch',
      data: {
        'branch_id': branchId,
        if (role != null && role.isNotEmpty) 'role': role,
      },
    );
    return _persistAuthResponse(response.data!);
  }

  Future<AuthUser> _persistAuthResponse(Map<String, dynamic> body) async {
    final api = ApiResponse<Map<String, dynamic>>.fromJson(
      body,
      (d) => d as Map<String, dynamic>,
    );

    if (!api.success || api.data == null) {
      throw Exception(api.message);
    }

    final data = api.data!;
    await _storage.saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );

    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveUserJson(jsonEncode(data['user']));
    return user;
  }

  Future<AuthUser?> getCachedUser() async {
    final json = _storage.getUserJson();
    if (json == null) return null;
    return AuthUser.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> clearLocalSession() async {
    await _storage.clear();
  }

  Future<AuthUser> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/change-password',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
    final api = ApiResponse<dynamic>.fromJson(response.data!, (d) => d);
    if (!api.success) throw Exception(api.message);

    final cached = await getCachedUser();
    if (cached == null) throw Exception('Sesi tidak ditemukan');

    final updated = AuthUser(
      id: cached.id,
      name: cached.name,
      email: cached.email,
      role: cached.role,
      roles: cached.roles,
      globalRoles: cached.globalRoles,
      branchAssignments: cached.branchAssignments,
      tenantId: cached.tenantId,
      branchId: cached.branchId,
      branchIds: cached.branchIds,
      branches: cached.branches,
      tenantName: cached.tenantName,
      branchName: cached.branchName,
      mustChangePassword: false,
    );
    await _storage.saveUserJson(jsonEncode({
      'id': updated.id,
      'name': updated.name,
      'email': updated.email,
      'role': updated.role,
      'roles': updated.roles,
      'global_roles': updated.globalRoles,
      'tenant_id': updated.tenantId,
      'branch_id': updated.branchId,
      'branch_ids': updated.branchIds,
      'branches': updated.branches
          .map((b) => {'id': b.id, 'name': b.name, 'code': b.code})
          .toList(),
      'must_change_password': false,
    }));
    return updated;
  }

  Future<void> logout() async {
    final refresh = await _storage.getRefreshToken();
    try {
      if (refresh != null) {
        await _dio.post('/auth/logout', data: {'refresh_token': refresh});
      }
    } catch (_) {}
    await clearLocalSession();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
});
