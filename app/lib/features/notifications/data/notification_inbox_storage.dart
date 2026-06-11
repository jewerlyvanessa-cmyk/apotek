import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/entities/app_notification.dart';

const _keyInbox = 'notifications_inbox_v1';

class NotificationInboxStorage {
  NotificationInboxStorage(this._prefs);
  final SharedPreferences _prefs;

  List<AppNotification> getAll() {
    final raw = _prefs.getString(_keyInbox);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => AppNotification.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> setAll(List<AppNotification> items) async {
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyInbox, raw);
  }

  Future<void> add(AppNotification n, {int max = 200}) async {
    final items = getAll();
    final next = [n, ...items].take(max).toList();
    await setAll(next);
  }

  Future<void> markRead(String id, bool read) async {
    final items = getAll();
    final next = items.map((n) => n.id == id ? n.copyWith(isRead: read) : n).toList();
    await setAll(next);
  }

  Future<void> remove(String id) async {
    final items = getAll().where((n) => n.id != id).toList();
    await setAll(items);
  }

  Future<void> clear() async {
    await _prefs.remove(_keyInbox);
  }
}

