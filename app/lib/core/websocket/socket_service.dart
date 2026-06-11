import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../app/config/app_config.dart';
import '../storage/token_storage.dart';
import 'socket_events.dart';

typedef SocketEventCallback = void Function(Map<String, dynamic> payload);

class SocketService {
  SocketService(this._config, this._tokenStorage);

  final AppConfig _config;
  final TokenStorage _tokenStorage;
  io.Socket? _socket;
  final _listeners = <String, List<SocketEventCallback>>{};

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    final token = await _tokenStorage.getAccessToken();
    if (token == null) return;

    disconnect();

    _socket = io.io(
      _config.wsBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {});
    for (final event in [
      SocketEvents.stockUpdated,
      SocketEvents.stockLow,
      SocketEvents.batchExpired,
      SocketEvents.orderCreated,
      SocketEvents.orderUpdated,
      SocketEvents.paymentCompleted,
    ]) {
      _socket!.on(event, (data) => _dispatch(event, data));
    }
  }

  void _dispatch(String event, dynamic data) {
    if (data is! Map) return;
    final payload = Map<String, dynamic>.from(data);
    final list = _listeners[event];
    if (list == null) return;
    for (final listener in List<SocketEventCallback>.from(list)) {
      listener(payload);
    }
  }

  void on(String event, SocketEventCallback callback) {
    _listeners.putIfAbsent(event, () => []).add(callback);
  }

  void off(String event, SocketEventCallback callback) {
    _listeners[event]?.remove(callback);
  }

  void onStockUpdate(SocketEventCallback callback) {
    on(SocketEvents.stockUpdated, callback);
    on(SocketEvents.stockLow, callback);
  }

  void offStockUpdate(SocketEventCallback callback) {
    off(SocketEvents.stockUpdated, callback);
    off(SocketEvents.stockLow, callback);
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _listeners.clear();
  }
}

final socketServiceProvider = Provider<SocketService>((ref) {
  throw UnimplementedError('socketServiceProvider must be overridden');
});
