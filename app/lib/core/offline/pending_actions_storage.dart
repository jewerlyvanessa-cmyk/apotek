import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'pending_action.dart';

const _pendingActionsKeyV1 = 'pending_actions_v1';
const _pendingActionsKeyV2 = 'pending_actions_v2';

class PendingActionsStorage {
  PendingActionsStorage(this._prefs);

  final SharedPreferences _prefs;

  List<PendingAction> getAll() {
    final raw = _prefs.getString(_pendingActionsKeyV2) ?? _prefs.getString(_pendingActionsKeyV1);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => PendingAction.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  PendingAction? getById(String id) {
    final items = getAll();
    for (final a in items) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<void> setAll(List<PendingAction> items) async {
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await _prefs.setString(_pendingActionsKeyV2, raw);
  }

  Future<void> add(PendingAction action) async {
    final items = getAll();
    await setAll([action, ...items]);
  }

  Future<void> removeById(String id) async {
    final items = getAll().where((a) => a.id != id).toList();
    await setAll(items);
  }

  Future<void> upsert(PendingAction action) async {
    final items = getAll();
    final updated = <PendingAction>[];
    var replaced = false;
    for (final a in items) {
      if (a.id == action.id) {
        updated.add(action);
        replaced = true;
      } else {
        updated.add(a);
      }
    }
    if (!replaced) updated.insert(0, action);
    await setAll(updated);
  }

  Future<void> clear() async {
    await _prefs.remove(_pendingActionsKeyV2);
    await _prefs.remove(_pendingActionsKeyV1);
  }
}

