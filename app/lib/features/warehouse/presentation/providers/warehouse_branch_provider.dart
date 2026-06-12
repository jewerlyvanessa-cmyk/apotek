import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../inventory/presentation/providers/stock_provider.dart';

/// Cabang aktif untuk opname/transfer gudang.
/// Owner/Manager multi-cabang: pilih manual; selain itu: cabang user / satu-satunya cabang.
final warehouseBranchIdProvider = StateProvider<String?>((ref) {
  final user = ref.read(authProvider).user;
  if (user == null) return null;
  if (user.isTenantWideManager) return null;
  if (user.branchId != null) return user.branchId;
  final allowed = user.assignedBranchIds;
  return allowed.length == 1 ? allowed.first : null;
});

/// Perlu pilih cabang hanya jika manajer pusat dan tenant punya >1 cabang aktif.
final warehouseNeedsBranchPickerProvider = Provider<bool>((ref) {
  final user = ref.watch(authProvider).user;
  if (user?.isTenantWideManager != true) return false;
  final count = ref.watch(tenantActiveBranchCountProvider).valueOrNull;
  return (count ?? 2) > 1;
});

/// Cabang efektif untuk opname/terima stok — auto jika tenant hanya 1 cabang.
final effectiveWarehouseBranchIdProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider).user;
  if (user == null) return null;

  final manual = ref.watch(warehouseBranchIdProvider);
  if (!user.isTenantWideManager) {
    return manual ??
        user.branchId ??
        (user.assignedBranchIds.length == 1
            ? user.assignedBranchIds.first
            : null);
  }

  return ref.watch(tenantActiveBranchesProvider).maybeWhen(
        data: (branches) {
          if (branches.length == 1) {
            return branches.first['id']?.toString();
          }
          return manual;
        },
        orElse: () => manual,
      );
});
