import 'package:dio/dio.dart';
import 'pending_action.dart';
import 'pending_actions_storage.dart';

class SyncResult {
  const SyncResult({
    required this.succeeded,
    required this.failed,
    required this.remaining,
    required this.conflicts,
  });

  final int succeeded;
  final int failed;
  final int remaining;
  final int conflicts;
}

class SyncManager {
  SyncManager(this._dio, this._storage);

  final Dio _dio;
  final PendingActionsStorage _storage;

  List<PendingAction> get queue => _storage.getAll();

  Future<void> enqueueCreateOrder({
    String? customerId,
    required String? customerName,
    String? customerPhone,
    required List<Map<String, dynamic>> items,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _storage.add(
      PendingAction(
        id: id,
        createdAtIso: DateTime.now().toIso8601String(),
        type: 'CREATE_ORDER',
        payload: {
          if (customerId != null && customerId.isNotEmpty) 'customer_id': customerId,
          if (customerName != null && customerName.trim().isNotEmpty)
            'customer_name': customerName.trim(),
          if (customerPhone != null && customerPhone.trim().isNotEmpty)
            'customer_phone': customerPhone.trim(),
          'items': items,
        },
      ),
    );
  }

  Future<void> enqueuePayOrder({
    required String orderId,
    required String paymentMethod,
    required double amount,
    double? amountReceived,
    String? proofImageUrl,
    List<Map<String, dynamic>>? splits,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _storage.add(
      PendingAction(
        id: id,
        createdAtIso: DateTime.now().toIso8601String(),
        type: 'PAY_ORDER',
        payload: splits != null && splits.isNotEmpty
            ? {
                'order_id': orderId,
                'splits': splits,
              }
            : {
                'order_id': orderId,
                'payment_method': paymentMethod,
                'amount': amount.round(),
                if (amountReceived != null)
                  'amount_received': amountReceived.round(),
                if (proofImageUrl != null && proofImageUrl.isNotEmpty)
                  'proof_image_url': proofImageUrl,
              },
      ),
    );
  }

  Future<void> enqueueAdjustStock({
    required String medicineId,
    required int quantity,
    String? branchId,
    String? batchId,
    String? notes,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _storage.add(
      PendingAction(
        id: id,
        createdAtIso: DateTime.now().toIso8601String(),
        type: 'ADJUST_STOCK',
        payload: {
          'medicine_id': medicineId,
          'quantity': quantity,
          ...?branchId != null ? {'branch_id': branchId} : null,
          ...?batchId != null ? {'batch_id': batchId} : null,
          ...?notes != null ? {'notes': notes} : null,
        },
      ),
    );
  }

  Future<void> enqueueCashEntry({
    required String type,
    required double amount,
    required String branchId,
    String? category,
    String? notes,
    String? entryDate,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _storage.add(
      PendingAction(
        id: id,
        createdAtIso: DateTime.now().toIso8601String(),
        type: 'CASH_ENTRY',
        payload: {
          'type': type,
          'amount': amount.round(),
          'branch_id': branchId,
          ...?category != null ? {'category': category} : null,
          ...?notes != null ? {'notes': notes} : null,
          ...?entryDate != null ? {'entry_date': entryDate} : null,
        },
      ),
    );
  }

  Future<void> enqueueStockMutation({
    required String medicineId,
    required int quantity,
    required String movementType,
    String? branchId,
    String? batchId,
    String? notes,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _storage.add(
      PendingAction(
        id: id,
        createdAtIso: DateTime.now().toIso8601String(),
        type: 'STOCK_MUTATION',
        payload: {
          'medicine_id': medicineId,
          'quantity': quantity,
          'movement_type': movementType,
          ...?branchId != null ? {'branch_id': branchId} : null,
          ...?batchId != null ? {'batch_id': batchId} : null,
          ...?notes != null ? {'notes': notes} : null,
        },
      ),
    );
  }

  Future<bool> processOne(String id) async {
    final action = _storage.getById(id);
    if (action == null) return true;
    try {
      await _processAction(action);
      await _storage.removeById(action.id);
      return true;
    } on DioException catch (e) {
      if (e.response == null) return false; // still offline
      // 401: interceptor memutus sesi; biarkan status antrian tetap QUEUED.
      if (e.response?.statusCode == 401) return false;
      final updated = _markRejected(action, e);
      // For idempotent "already applied" cases -> treat as success and drop.
      if (_isEffectivelySuccess(action, e)) {
        await _storage.removeById(action.id);
        return true;
      }
      await _storage.upsert(updated);
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<SyncResult> processQueue({int max = 20}) async {
    final items = _storage.getAll();
    if (items.isEmpty) {
      return const SyncResult(succeeded: 0, failed: 0, remaining: 0, conflicts: 0);
    }

    var succeeded = 0;
    var failed = 0;
    var conflicts = 0;

    for (final action in items.take(max)) {
      try {
        await _processAction(action);
        await _storage.removeById(action.id);
        succeeded++;
      } on DioException catch (e) {
        // Stop early on network/offline, keep remaining actions.
        if (e.response == null) break;
        // Sesi habis: logout via interceptor, jangan tandai antrian gagal.
        if (e.response?.statusCode == 401) break;
        // For idempotent "already applied" cases -> drop & count success.
        if (_isEffectivelySuccess(action, e)) {
          await _storage.removeById(action.id);
          succeeded++;
          continue;
        }

        final updated = _markRejected(action, e);
        await _storage.upsert(updated);
        if (updated.status == 'CONFLICT') {
          conflicts++;
        } else {
          failed++;
        }
      } catch (_) {
        // Unexpected -> keep the queue intact and stop.
        break;
      }
    }

    final remaining = _storage.getAll().length;
    return SyncResult(
      succeeded: succeeded,
      failed: failed,
      remaining: remaining,
      conflicts: conflicts,
    );
  }

  Future<void> _processAction(PendingAction action) async {
    switch (action.type) {
      case 'CREATE_ORDER':
        await _dio.post('/orders', data: action.payload);
        return;
      case 'PAY_ORDER':
        await _dio.post('/payments', data: action.payload);
        return;
      case 'ADJUST_STOCK':
        await _dio.post('/stocks/adjust', data: action.payload);
        return;
      case 'STOCK_MUTATION':
        await _dio.post('/stocks/mutation', data: action.payload);
        return;
      case 'CASH_ENTRY':
        await _dio.post('/cash-entries', data: action.payload);
        return;
      default:
        // unknown type -> treat as failure and let caller decide
        throw StateError('Unknown pending action type: ${action.type}');
    }
  }

  bool _isEffectivelySuccess(PendingAction action, DioException e) {
    final status = e.response?.statusCode;
    final msg = _extractMessage(e);
    if (action.type == 'PAY_ORDER' && status == 400) {
      // Server says it's not waiting payment -> likely already paid / not payable.
      if (msg.toLowerCase().contains('not waiting for payment')) return true;
    }
    return false;
  }

  PendingAction _markRejected(PendingAction action, DioException e) {
    final status = e.response?.statusCode;
    final msg = _extractMessage(e);
    final nextAttempts = action.attempts + 1;
    final nextStatus = _isConflict(status) ? 'CONFLICT' : 'FAILED';
    return action.copyWith(
      status: nextStatus,
      attempts: nextAttempts,
      lastHttpStatus: status,
      lastError: msg,
      updatedAtIso: DateTime.now().toIso8601String(),
    );
  }

  bool _isConflict(int? status) => status == 409 || status == 422;

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
      // Nest validation sometimes returns array
      if (message is List && message.isNotEmpty) return message.first.toString();
    }
    return e.message ?? e.toString();
  }
}

