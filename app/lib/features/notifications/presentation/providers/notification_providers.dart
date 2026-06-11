import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/printing/printer_providers.dart';
import '../../../../core/websocket/socket_events.dart';
import '../../../../core/websocket/socket_service.dart';
import '../../data/notification_inbox_storage.dart';
import '../../domain/entities/app_notification.dart';

final notificationInboxStorageProvider = Provider<NotificationInboxStorage>((ref) {
  return NotificationInboxStorage(ref.watch(prefsProvider));
});

final notificationInboxProvider = StateNotifierProvider<NotificationInboxNotifier, List<AppNotification>>(
  (ref) => NotificationInboxNotifier(ref),
);

class NotificationInboxNotifier extends StateNotifier<List<AppNotification>> {
  NotificationInboxNotifier(this._ref) : super(const []) {
    _load();
  }

  final Ref _ref;

  NotificationInboxStorage get _storage => _ref.read(notificationInboxStorageProvider);

  void _load() {
    state = _storage.getAll();
  }

  Future<void> refresh() async {
    _load();
  }

  Future<void> add(AppNotification n) async {
    await _storage.add(n);
    _load();
  }

  Future<void> markRead(String id, bool read) async {
    await _storage.markRead(id, read);
    _load();
  }

  Future<void> remove(String id) async {
    await _storage.remove(id);
    _load();
  }

  Future<void> clear() async {
    await _storage.clear();
    _load();
  }
}

final unreadCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationInboxProvider);
  return items.where((n) => !n.isRead).length;
});

/// Attach socket listeners once per app run.
final notificationListenerProvider = Provider<void>((ref) {
  final socket = ref.watch(socketServiceProvider);
  final inbox = ref.read(notificationInboxProvider.notifier);

  void push(String type, String title, String body, Map<String, dynamic> payload) {
    final id = '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    inbox.add(
      AppNotification(
        id: id,
        createdAtIso: DateTime.now().toIso8601String(),
        title: title,
        body: body,
        type: type,
        payload: payload,
      ),
    );
  }

  void onStockLow(Map<String, dynamic> p) {
    final name = (p['medicine_name'] as String?) ?? 'Obat';
    final avail = p['available_quantity']?.toString() ?? '-';
    push('stock_low', 'Stok menipis', '$name · sisa $avail', p);
  }

  void onBatchExpired(Map<String, dynamic> p) {
    final name = (p['medicine_name'] as String?) ?? 'Obat';
    final left = p['days_left']?.toString();
    final msg = left == null ? '$name · batch expired' : '$name · $left hari';
    push('batch_expired', 'Expired alert', msg, p);
  }

  void onPayment(Map<String, dynamic> p) {
    final no = p['order_number']?.toString() ?? p['order_id']?.toString() ?? '-';
    final amt = p['amount']?.toString() ?? '';
    push('payment', 'Pembayaran selesai', '$no · $amt', p);
  }

  void onOrderCreated(Map<String, dynamic> p) {
    final no = p['order_number']?.toString() ?? '-';
    push('order', 'Order baru', no, p);
  }

  void onOrderUpdated(Map<String, dynamic> p) {
    final status = p['status']?.toString() ?? '-';
    final id = p['order_id']?.toString() ?? '-';
    push('order', 'Order update', '$id · $status', p);
  }

  void onSubscriptionWarning(Map<String, dynamic> p) {
    final name = p['tenant_name']?.toString() ?? 'Tenant';
    final days = p['days_left'];
    final daysNum = days is num ? days.toInt() : int.tryParse('$days');
    final body = daysNum == null
        ? 'Periksa status langganan $name'
        : daysNum < 0
            ? '$name kedaluwarsa ${daysNum.abs()} hari lalu'
            : '$name berakhir dalam $daysNum hari';
    push('subscription', 'Peringatan langganan', body, p);
  }

  socket.on(SocketEvents.stockLow, onStockLow);
  socket.on(SocketEvents.batchExpired, onBatchExpired);
  socket.on(SocketEvents.paymentCompleted, onPayment);
  socket.on(SocketEvents.orderCreated, onOrderCreated);
  socket.on(SocketEvents.orderUpdated, onOrderUpdated);
  socket.on(SocketEvents.subscriptionWarning, onSubscriptionWarning);

  ref.onDispose(() {
    socket.off(SocketEvents.stockLow, onStockLow);
    socket.off(SocketEvents.batchExpired, onBatchExpired);
    socket.off(SocketEvents.paymentCompleted, onPayment);
    socket.off(SocketEvents.orderCreated, onOrderCreated);
    socket.off(SocketEvents.orderUpdated, onOrderUpdated);
    socket.off(SocketEvents.subscriptionWarning, onSubscriptionWarning);
  });
});

