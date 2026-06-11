import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/utils/role_labels.dart';
import '../../domain/entities/auth_user.dart';

class SessionContextPick {
  const SessionContextPick({
    required this.role,
    this.branchId,
  });

  final String role;
  final String? branchId;

  bool changedFrom(AuthUser user) =>
      role != user.role || branchId != user.branchId;
}

List<AuthBranch> _resolvedBranches(AuthUser user) {
  if (user.branches.isNotEmpty) return user.branches;
  return user.branchAssignments
      .map(
        (a) => AuthBranch(
          id: a.branchId,
          name: a.branchName.isNotEmpty ? a.branchName : a.branchId,
          code: a.branchCode,
        ),
      )
      .toList();
}

String _roleLabel(AuthUser user, String role, String? branchId) {
  if (role == 'MANAGER') {
    final atBranch = branchId != null &&
        user.branchAssignments.any(
          (a) => a.branchId == branchId && a.roles.contains('MANAGER'),
        );
    return RoleLabels.label(
      role,
      branchId: atBranch ? branchId : null,
    );
  }
  return RoleLabels.label(role);
}

List<String> _rolesForBranch(AuthUser user, String? branchId) {
  return AuthUser.rolesForContext(
    globalRoles: user.globalRoles,
    assignments: user.branchAssignments,
    branchId: branchId,
    fallback: user.role,
  );
}

List<AuthBranch> _branchesForRole(AuthUser user, String role) {
  if (role == 'OWNER' && user.globalRoles.contains('OWNER')) {
    return _resolvedBranches(user);
  }
  final ids = user.branchesForRole(role).toSet();
  if (role == 'MANAGER' && user.globalRoles.contains('MANAGER')) {
    ids.addAll(user.branchIds);
  }
  return _resolvedBranches(user).where((b) => ids.contains(b.id)).toList();
}

Future<SessionContextPick?> showSessionContextPickerDialog(
  BuildContext context, {
  required AuthUser user,
  bool requireChange = false,
}) {
  final allBranches = _resolvedBranches(user);
  final hasBranches = allBranches.isNotEmpty;
  final hasGlobalOnly = user.globalRoles.isNotEmpty && !hasBranches;

  var selectedBranchId = user.branchId ??
      (allBranches.length == 1 ? allBranches.first.id : null);
  var selectedRole = user.role;

  if (selectedBranchId != null) {
    final atBranch = _rolesForBranch(user, selectedBranchId);
    if (!atBranch.contains(selectedRole) && atBranch.isNotEmpty) {
      selectedRole = atBranch.first;
    }
  }

  final showBranches = hasBranches && allBranches.length > 1;
  final initialRoles = _rolesForBranch(
    user,
    hasGlobalOnly ? null : selectedBranchId,
  );
  final needsDialog = showBranches ||
      initialRoles.length > 1 ||
      hasGlobalOnly;

  if (!needsDialog) return Future.value(null);

  return showDialog<SessionContextPick>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final roles = _rolesForBranch(
          user,
          hasGlobalOnly ? null : selectedBranchId,
        );
        final branches = selectedRole.isEmpty
            ? allBranches
            : _branchesForRole(user, selectedRole);
        final showRoleSection = roles.length > 1 || hasGlobalOnly;

        final pick = SessionContextPick(
          role: selectedRole,
          branchId: hasBranches ? selectedBranchId : null,
        );
        final unchanged = !pick.changedFrom(user);

        return AlertDialog(
          title: const Text('Sesuaikan peran & cabang'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showBranches) ...[
                  const Text(
                    'Cabang aktif',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...branches.map((b) {
                    final selected = b.id == selectedBranchId;
                    final branchRoleSummary = _rolesForBranch(user, b.id)
                        .map((r) => _roleLabel(user, r, b.id))
                        .join(', ');
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                      title: Text(
                        b.name,
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      subtitle: branchRoleSummary.isNotEmpty
                          ? Text(
                              branchRoleSummary,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : null,
                      onTap: () {
                        setLocal(() {
                          selectedBranchId = b.id;
                          final atBranch = _rolesForBranch(user, b.id);
                          if (!atBranch.contains(selectedRole)) {
                            selectedRole =
                                atBranch.isNotEmpty ? atBranch.first : selectedRole;
                          }
                        });
                      },
                    );
                  }),
                  if (showRoleSection) const SizedBox(height: AppSpacing.md),
                ],
                if (showRoleSection) ...[
                  const Text(
                    'Peran aktif',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (selectedBranchId != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Hanya peran yang ditugaskan di cabang ini.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  ...roles.map((r) {
                    final selected = r == selectedRole;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                      title: Text(
                        _roleLabel(user, r, selectedBranchId),
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      subtitle: _roleLabel(user, r, selectedBranchId) != r
                          ? Text(
                              r,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : null,
                      onTap: () {
                        setLocal(() => selectedRole = r);
                        final allowedBranches = _branchesForRole(user, r);
                        if (selectedBranchId != null &&
                            allowedBranches.isNotEmpty &&
                            !allowedBranches.any((b) => b.id == selectedBranchId)) {
                          selectedBranchId = allowedBranches.first.id;
                        }
                      },
                    );
                  }),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: requireChange && unchanged
                  ? null
                  : () => Navigator.pop(
                        ctx,
                        SessionContextPick(
                          role: selectedRole,
                          branchId: hasBranches ? selectedBranchId : null,
                        ),
                      ),
              child: const Text('Terapkan'),
            ),
          ],
        );
      },
    ),
  );
}

/// Pilih cabang aktif — menampilkan ringkasan peran per cabang.
Future<String?> showBranchPickerDialog(
  BuildContext context, {
  required AuthUser user,
}) {
  final branches = _resolvedBranches(user);
  if (branches.length <= 1) return Future.value(null);

  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Pilih cabang aktif'),
      children: [
        ...branches.map((b) {
          final isActive = b.id == user.branchId;
          final roleSummary = _rolesForBranch(user, b.id)
              .map((r) => _roleLabel(user, r, b.id))
              .join(', ');
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, b.id),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isActive)
                  const Icon(Icons.check, size: 18, color: AppColors.primary)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isActive ? '${b.name} (aktif)' : b.name,
                        style: TextStyle(
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      if (roleSummary.isNotEmpty)
                        Text(
                          roleSummary,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ],
    ),
  );
}

/// Peran yang valid di cabang aktif user.
String resolveRoleForBranch(AuthUser user, String branchId) {
  final atBranch = AuthUser.rolesForContext(
    globalRoles: user.globalRoles,
    assignments: user.branchAssignments,
    branchId: branchId,
    fallback: user.role,
  );
  if (atBranch.contains(user.role)) return user.role;
  return atBranch.isNotEmpty ? atBranch.first : user.role;
}

/// Pilih peran aktif di cabang saat ini.
Future<String?> showSessionRolePickerDialog(
  BuildContext context, {
  required AuthUser user,
}) {
  final roles = _rolesForBranch(user, user.branchId);
  if (roles.length <= 1) return Future.value(null);

  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(
        user.branchName != null && user.branchName!.isNotEmpty
            ? 'Pilih peran · ${user.branchName}'
            : 'Pilih peran aktif',
      ),
      children: [
        ...roles.map((r) {
          final isActive = r == user.role;
          final label = _roleLabel(user, r, user.branchId);
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, r),
            child: Row(
              children: [
                if (isActive)
                  const Icon(Icons.check, size: 18, color: AppColors.primary)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      if (label != r)
                        Text(
                          r,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ],
    ),
  );
}
