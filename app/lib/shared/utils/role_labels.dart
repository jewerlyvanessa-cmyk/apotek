import '../../features/auth/domain/entities/auth_user.dart';

abstract final class RoleLabels {
  static const managerCentral = 'Manajer Pusat';
  static const managerBranch = 'Kepala Cabang';

  static const _labels = <String, String>{
    'SUPER_ADMIN': 'Super Admin',
    'OWNER': 'Owner',
    'MANAGER': managerCentral,
    'PHARMACIST': 'Apoteker',
    'CASHIER': 'Kasir',
    'STAFF': 'Asisten',
    'WAREHOUSE': 'Gudang',
  };

  static String label(String role, {String? branchId}) {
    if (role == 'MANAGER') {
      if (branchId != null && branchId.isNotEmpty) return managerBranch;
      return managerCentral;
    }
    return _labels[role] ?? role;
  }

  static String labelForUser(AuthUser user) =>
      label(user.role, branchId: user.branchId);

  static String labelFromMap(Map<String, dynamic> user, String role) =>
      label(role, branchId: _branchIdFromMap(user));

  static String? _branchIdFromMap(Map<String, dynamic> user) {
    final direct = user['branchId']?.toString() ?? user['branch_id']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final branches = user['branches'];
    if (branches is List && branches.isNotEmpty) {
      final first = branches.first;
      if (first is Map) return first['id']?.toString();
    }
    final branchIds = user['branch_ids'];
    if (branchIds is List && branchIds.isNotEmpty) {
      return branchIds.first.toString();
    }
    final branch = user['branch'];
    if (branch is Map) return branch['id']?.toString();
    return null;
  }

  static bool hasAssignedBranches(Map<String, dynamic> user) {
    final branches = user['branches'];
    if (branches is List && branches.isNotEmpty) return true;
    final branchIds = user['branch_ids'];
    if (branchIds is List && branchIds.isNotEmpty) return true;
    return _branchIdFromMap(user) != null;
  }
}
