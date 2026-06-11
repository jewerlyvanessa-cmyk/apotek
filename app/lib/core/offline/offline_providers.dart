import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_client.dart';
import 'pending_actions_storage.dart';
import 'sync_manager.dart';

final pendingActionsStorageProvider = Provider<PendingActionsStorage>((ref) {
  throw UnimplementedError('pendingActionsStorageProvider must be overridden');
});

final syncManagerProvider = Provider<SyncManager>((ref) {
  return SyncManager(
    ref.watch(dioProvider),
    ref.watch(pendingActionsStorageProvider),
  );
});

final pendingActionsCountProvider = Provider<int>((ref) {
  return ref.watch(syncManagerProvider).queue.length;
});

