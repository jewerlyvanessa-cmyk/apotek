import 'package:equatable/equatable.dart';

class AuthBranch extends Equatable {
  const AuthBranch({
    required this.id,
    required this.name,
    this.code,
  });

  final String id;
  final String name;
  final String? code;

  factory AuthBranch.fromJson(Map<String, dynamic> json) {
    return AuthBranch(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, name];
}

class BranchAssignment extends Equatable {
  const BranchAssignment({
    required this.branchId,
    required this.branchName,
    required this.roles,
    this.branchCode,
  });

  final String branchId;
  final String branchName;
  final String? branchCode;
  final List<String> roles;

  factory BranchAssignment.fromJson(Map<String, dynamic> json) {
    final branch = json['branch'] as Map<String, dynamic>?;
    final rawRoles = json['roles'];
    return BranchAssignment(
      branchId: json['branch_id'] as String? ??
          branch?['id'] as String? ??
          '',
      branchName: branch?['name'] as String? ?? '',
      branchCode: branch?['code'] as String?,
      roles: rawRoles is List
          ? rawRoles.map((e) => e.toString()).toList()
          : const [],
    );
  }

  @override
  List<Object?> get props => [branchId, roles];
}

class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.roles = const [],
    this.globalRoles = const [],
    this.branchAssignments = const [],
    this.tenantId,
    this.branchId,
    this.branchIds = const [],
    this.branches = const [],
    this.tenantName,
    this.branchName,
    this.mustChangePassword = false,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final List<String> roles;
  final List<String> globalRoles;
  final List<BranchAssignment> branchAssignments;
  final String? tenantId;
  final String? branchId;
  final List<String> branchIds;
  final List<AuthBranch> branches;
  final String? tenantName;
  final String? branchName;
  final bool mustChangePassword;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final tenant = json['tenant'] as Map<String, dynamic>?;
    final branch = json['branch'] as Map<String, dynamic>?;
    final activeRole = json['role'] as String;

    final rawGlobal = json['global_roles'];
    final globalRoles = rawGlobal is List
        ? rawGlobal.map((e) => e.toString()).toList()
        : <String>[];

    final rawAssignments = json['branch_assignments'];
    final branchAssignments = rawAssignments is List
        ? rawAssignments
            .map(
              (e) => BranchAssignment.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList()
        : <BranchAssignment>[];

    final rawBranches = json['branches'];
    final branches = rawBranches is List
        ? rawBranches
            .map((e) => AuthBranch.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <AuthBranch>[];

    final rawBranchIds = json['branch_ids'];
    var branchIds = rawBranchIds is List
        ? rawBranchIds.map((e) => e.toString()).toList()
        : <String>[];
    if (branchIds.isEmpty && branchAssignments.isNotEmpty) {
      branchIds = branchAssignments.map((a) => a.branchId).toList();
    } else if (branchIds.isEmpty && branches.isNotEmpty) {
      branchIds = branches.map((b) => b.id).toList();
    }

    final sessionRoles = _sessionRolesFromParts(
      globalRoles,
      branchAssignments,
      json['branch_id'] as String?,
      json['roles'],
      activeRole,
    );

    var resolvedBranchId = json['branch_id'] as String?;
    if ((resolvedBranchId == null || resolvedBranchId.isEmpty) &&
        branchIds.length == 1) {
      resolvedBranchId = branchIds.first;
    }

    return AuthUser(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['full_name'] as String? ?? '',
      email: json['email'] as String,
      role: activeRole,
      roles: sessionRoles,
      globalRoles: globalRoles,
      branchAssignments: branchAssignments,
      tenantId: json['tenant_id'] as String?,
      branchId: resolvedBranchId,
      branchIds: branchIds,
      branches: branches,
      tenantName: tenant?['name'] as String?,
      branchName: branch?['name'] as String?,
      mustChangePassword: json['must_change_password'] == true,
    );
  }

  static List<String> _sessionRolesFromParts(
    List<String> globalRoles,
    List<BranchAssignment> assignments,
    String? branchId,
    Object? rawRoles,
    String activeRole,
  ) {
    if (rawRoles is List && rawRoles.isNotEmpty) {
      return rawRoles.map((e) => e.toString()).toList();
    }
    return rolesForContext(
      globalRoles: globalRoles,
      assignments: assignments,
      branchId: branchId,
      fallback: activeRole,
    );
  }

  static List<String> rolesForContext({
    required List<String> globalRoles,
    required List<BranchAssignment> assignments,
    String? branchId,
    String? fallback,
  }) {
    if (branchId == null || branchId.isEmpty) {
      final branchUnion =
          assignments.expand((a) => a.roles).map((e) => e).toSet();
      final all = {...globalRoles, ...branchUnion};
      if (all.isNotEmpty) return all.toList();
      return fallback != null ? [fallback] : [];
    }
    final branchRoles = assignments
            .where((a) => a.branchId == branchId)
            .expand((a) => a.roles)
            .toSet()
            .toList();
    final global = globalRoles.where((r) => r == 'OWNER').toList();
    final merged = {...global, ...branchRoles};
    if (merged.isNotEmpty) return merged.toList();
    return fallback != null ? [fallback] : [];
  }

  List<String> rolesAtBranch(String? id) => rolesForContext(
        globalRoles: globalRoles,
        assignments: branchAssignments,
        branchId: id,
        fallback: role,
      );

  List<String> branchesForRole(String r) {
    final fromAssignments = branchAssignments
        .where((a) => a.roles.contains(r))
        .map((a) => a.branchId)
        .toList();
    if (fromAssignments.isNotEmpty) return fromAssignments;
    if (globalRoles.contains(r)) return branchIds;
    return const [];
  }

  bool get hasMultipleRoles => rolesAtBranch(branchId).length > 1;
  bool get hasMultipleBranches => branchIds.length > 1;

  /// Bisa ganti cabang aktif (>1 cabang ditugaskan).
  bool get canSwitchBranch => branchIds.length > 1;

  /// Bisa ganti peran di cabang aktif (>1 peran di cabang ini).
  bool get canSwitchRole => rolesAtBranch(branchId).length > 1;

  bool get canSwitchSession {
    if (branchAssignments.length > 1) return true;
    if (globalRoles.isNotEmpty && branchAssignments.isNotEmpty) return true;
    final multiRolesBranch = branchAssignments.any((a) => a.roles.length > 1);
    if (multiRolesBranch) return true;
    final distinctRoleSets = branchAssignments
        .map((a) => (List<String>.from(a.roles)..sort()).join(','))
        .toSet();
    if (distinctRoleSets.length > 1) return true;
    return rolesAtBranch(branchId).length > 1;
  }

  bool get isSuperAdmin => role == 'SUPER_ADMIN';
  bool get isOwner => role == 'OWNER';
  bool get isCashier => role == 'CASHIER';
  bool get isStaff => role == 'STAFF';
  bool get isWarehouse => role == 'WAREHOUSE';
  bool get isManager => role == 'MANAGER';
  bool get isPharmacist => role == 'PHARMACIST';

  bool hasAssignedRole(String r) =>
      globalRoles.contains(r) ||
      branchAssignments.any((a) => a.roles.contains(r));

  /// Cabang tempat peran aktif ditugaskan (mis. MANAGER → cabang yang dibawahi).
  List<String> get branchesForActiveRole {
    final scoped = branchAssignments
        .where((a) => a.roles.contains(role))
        .map((a) => a.branchId)
        .toList();
    if (scoped.isNotEmpty) return scoped;
    return assignedBranchIds;
  }

  /// Cabang yang dibawahi sebagai Kepala Cabang (peran MANAGER per cabang).
  List<String> get managedBranchIds => branchAssignments
      .where((a) => a.roles.contains('MANAGER'))
      .map((a) => a.branchId)
      .toList();

  /// Cabang yang boleh dilihat di modul stok (non tenant-wide = cabang login).
  List<String> get stockScopeBranchIds {
    if (branchId != null && branchId!.isNotEmpty) return [branchId!];
    if (assignedBranchIds.length == 1) return assignedBranchIds;
    return const [];
  }

  /// Owner atau Manajer Pusat — selaras API `isTenantWideUser`.
  bool get isTenantWideManager {
    if (role == 'OWNER') return true;
    if (role != 'MANAGER') return false;
    if (managedBranchIds.isNotEmpty) return false;
    return branchId == null || branchId!.isEmpty;
  }

  /// Alias historis — gunakan [isTenantWideManager].
  bool get isTenantAdmin => isTenantWideManager;

  /// Alias untuk modul stok — gunakan [isTenantWideManager].
  bool get isTenantWideStock => isTenantWideManager;

  /// Cabang yang boleh diakses (bukan tenant-wide).
  List<String> get assignedBranchIds => branchIds.isNotEmpty
      ? branchIds
      : (branchId != null && branchId!.isNotEmpty ? [branchId!] : const []);

  /// Owner atau Manajer Pusat — boleh kelola user tenant.
  bool get canManageUsers => isOwner || isTenantWideManager;

  /// Kepala cabang: MANAGER di cabang aktif (bukan Manajer Pusat).
  bool get isBranchManager {
    if (!isManager) return false;
    if (branchId == null || branchId!.isEmpty) return false;
    if (branchAssignments.isEmpty) return true;
    return branchAssignments.any(
      (a) => a.branchId == branchId && a.roles.contains('MANAGER'),
    );
  }

  String get contextTitle {
    if (branchId != null) {
      final branch = branchName?.trim();
      if (branch != null && branch.isNotEmpty) return branch;
    }
    final tenant = tenantName?.trim();
    if (tenant != null && tenant.isNotEmpty) return tenant;
    return 'Dashboard';
  }

  @override
  List<Object?> get props =>
      [id, email, role, roles, globalRoles, tenantId, branchId, branchIds];
}
