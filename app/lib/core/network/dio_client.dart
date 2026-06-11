import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/config/app_config.dart';
import '../auth/session_guard.dart';
import '../storage/token_storage.dart';
import 'network_online_provider.dart';
import 'ssl_pinning.dart';

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  configureDioSslPinning(dio);

  attachNetworkInterceptor(
    dio,
    (online) => ref.read(networkOnlineProvider.notifier).state = online,
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final path = error.requestOptions.path;
        if (status == 401) {
          final isPublicAuth = path.contains('/auth/login');
          if (!isPublicAuth) {
            await SessionGuard.instance.notifySessionExpired();
          }
        }
        if (status == 403) {
          final isLicenseActivate = path.contains('/license/activate');
          if (!isLicenseActivate) {
            final data = error.response?.data;
            if (data is Map) {
              final code = data['code']?.toString();
              if (code == 'SUBSCRIPTION_EXPIRED' ||
                  code == 'LICENSE_INVALID' ||
                  code == 'TENANT_INACTIVE' ||
                  code == 'BRANCH_INACTIVE') {
                await SessionGuard.instance.notifySessionExpired();
              }
            }
          }
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});

final appConfigProvider = StateProvider<AppConfig>((ref) {
  throw UnimplementedError('appConfigProvider must be overridden');
});
