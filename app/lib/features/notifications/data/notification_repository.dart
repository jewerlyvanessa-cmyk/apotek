import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/notifications/push_notification_service.dart';

class NotificationRepository {
  NotificationRepository(this._dio, this._push);

  final Dio _dio;
  final PushNotificationService _push;

  Future<void> registerDeviceToken() async {
    final token = await _push.getToken();
    if (token == null || token.isEmpty) return;

    final platform = kIsWeb
        ? 'web'
        : defaultTargetPlatform.name;

    final res = await _dio.post<Map<String, dynamic>>(
      '/notifications/device-token',
      data: {'token': token, 'platform': platform},
    );
    final api = ApiResponse<dynamic>.fromJson(res.data!, (d) => d);
    if (!api.success) throw Exception(api.message);
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(
    ref.watch(dioProvider),
    ref.watch(pushNotificationServiceProvider),
  );
});
