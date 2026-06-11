import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/setup_repository.dart';

final setupStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(setupRepositoryProvider).getStatus();
});

final databaseConfigProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(setupRepositoryProvider).getDatabaseConfig();
});
