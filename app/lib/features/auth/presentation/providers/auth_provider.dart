import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/websocket/socket_service.dart';
import '../../../../core/offline/offline_providers.dart';
import '../../../../core/offline/sync_manager.dart';
import '../../../notifications/data/notification_repository.dart';
import '../../data/auth_repository.dart';
import '../../domain/entities/auth_user.dart';

class AuthState {
  const AuthState({this.user, this.isLoading = false, this.error});

  final AuthUser? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({AuthUser? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(
    this._repo,
    this._socket,
    this._sync,
    this._notifications,
  ) : super(const AuthState()) {
    _loadCached();
  }

  final AuthRepository _repo;
  final SocketService _socket;
  final SyncManager _sync;
  final NotificationRepository _notifications;
  bool _endingSession = false;

  Future<void> _loadCached() async {
    final user = await _repo.getCachedUser();
    if (user != null) {
      state = AuthState(user: user);
      await _socket.connect();
      await _sync.processQueue();
      _registerPushToken();
    }
  }

  void _registerPushToken() {
    final user = state.user;
    if (user == null || user.isSuperAdmin || user.tenantId == null) return;
    // Best-effort — inbox WebSocket tetap jalan tanpa FCM.
    _notifications.registerDeviceToken().ignore();
  }

  Future<AuthUser?> login(String email, String password, {String? activeRole}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.login(
        email: email,
        password: password,
        activeRole: activeRole,
      );
      state = AuthState(user: user);
      await _socket.connect();
      await _sync.processQueue();
      _registerPushToken();
      return user;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _loginErrorMessage(e),
      );
      return null;
    }
  }

  Future<bool> switchRole(String role) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.switchRole(role);
      state = AuthState(user: user);
      await _socket.connect();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _loginErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> switchBranch(String branchId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.switchBranch(branchId);
      state = AuthState(user: user);
      await _socket.connect();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _loginErrorMessage(e),
      );
      return false;
    }
  }

  /// Terapkan peran & cabang aktif sesuai penugasan per cabang.
  Future<bool> switchSession({
    required String role,
    String? branchId,
  }) async {
    final current = state.user;
    if (current == null) return false;

    final roleChanged = role != current.role;
    final nextBranchId = branchId != null &&
            branchId.isNotEmpty &&
            branchId != current.branchId
        ? branchId
        : null;
    if (!roleChanged && nextBranchId == null) return true;

    state = state.copyWith(isLoading: true, error: null);
    try {
      AuthUser user;
      if (nextBranchId != null) {
        // Cabang dulu + peran target (validasi di API per cabang).
        user = await _repo.switchBranch(nextBranchId, role: role);
      } else if (roleChanged) {
        user = await _repo.switchRole(role);
      } else {
        return true;
      }
      state = AuthState(user: user);
      await _socket.connect();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _loginErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _loginErrorMessage(e),
      );
      return false;
    }
  }

  /// Token tidak valid / sesi habis — bersihkan lokal tanpa panggilan logout API.
  Future<void> sessionExpired() async {
    if (_endingSession || !state.isAuthenticated) return;
    _endingSession = true;
    try {
      _socket.disconnect();
      await _repo.clearLocalSession();
      state = const AuthState();
    } finally {
      _endingSession = false;
    }
  }

  Future<void> logout() async {
    if (_endingSession) return;
    _endingSession = true;
    try {
      _socket.disconnect();
      await _repo.logout();
      state = const AuthState();
    } finally {
      _endingSession = false;
    }
  }
}

String _loginErrorMessage(Object e) {
  if (e is DioException) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.unknown) {
      return 'Tidak dapat terhubung ke server. Pastikan backend berjalan '
          '(cd api && npm run start:dev).';
    }
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message']?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
    }
  }
  return e.toString().replaceFirst('Exception: ', '');
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(socketServiceProvider),
    ref.watch(syncManagerProvider),
    ref.watch(notificationRepositoryProvider),
  );
});
