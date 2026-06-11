import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Cabang aktif untuk opname/transfer gudang.
/// Owner/Manager: pilih manual; role lain: cabang user.
final warehouseBranchIdProvider = StateProvider<String?>((ref) {
  final user = ref.read(authProvider).user;
  if (user == null) return null;
  if (user.isTenantWideManager) return null;
  if (user.branchId != null) return user.branchId;
  final allowed = user.assignedBranchIds;
  return allowed.length == 1 ? allowed.first : null;
});

final warehouseNeedsBranchPickerProvider = Provider<bool>((ref) {
  final user = ref.watch(authProvider).user;
  return user?.isTenantWideManager == true;
});
