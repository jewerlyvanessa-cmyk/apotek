import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dio_client.dart';

final networkOnlineProvider = StateProvider<bool>((ref) => true);

/// Periodic health check + initial probe.
final networkHealthWatchProvider = Provider<void>((ref) {
  final dio = ref.watch(dioProvider);
  final notifier = ref.read(networkOnlineProvider.notifier);

  Future<void> probe() async {
    try {
      await dio.get<dynamic>(
        '/health',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      notifier.state = true;
    } catch (_) {
      notifier.state = false;
    }
  }

  unawaited(probe());
  final timer = Timer.periodic(const Duration(seconds: 30), (_) => probe());
  ref.onDispose(timer.cancel);
});

void attachNetworkInterceptor(Dio dio, void Function(bool online) setOnline) {
  dio.interceptors.add(
    InterceptorsWrapper(
      onResponse: (response, handler) {
        setOnline(true);
        handler.next(response);
      },
      onError: (error, handler) {
        if (_isOfflineError(error)) setOnline(false);
        handler.next(error);
      },
    ),
  );
}

bool _isOfflineError(DioException error) {
  return error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      (error.response == null && error.type != DioExceptionType.cancel);
}
