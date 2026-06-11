import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/license_repository.dart';
import '../../domain/entities/license_status.dart';

final licenseStatusProvider =
    FutureProvider.autoDispose<LicenseStatus>((ref) async {
  final auth = ref.watch(authProvider);
  final repo = ref.watch(licenseRepositoryProvider);
  if (auth.isAuthenticated) {
    return repo.getMyStatus();
  }
  return repo.getStatus();
});
