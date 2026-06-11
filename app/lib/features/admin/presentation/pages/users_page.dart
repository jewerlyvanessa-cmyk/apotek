import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/paginated_result.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/utils/role_labels.dart';
import '../../../../shared/widgets/pagination_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/admin_repository.dart';

final _usersPageProvider = StateProvider.autoDispose<int>((ref) => 1);

final _usersProvider =
    FutureProvider.autoDispose<PaginatedResult<Map<String, dynamic>>>((ref) async {
  final page = ref.watch(_usersPageProvider);
  return ref.watch(adminRepositoryProvider).listUsers(page: page);
});

final _branchesProviderForUsers =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminRepositoryProvider).listBranches();
});

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _RoleChipDef {
  const _RoleChipDef({
    required this.key,
    required this.label,
    required this.dbRole,
    this.managerWithBranch = false,
  });

  /// Kunci unik chip UI (bukan selalu sama dengan kode DB).
  final String key;
  final String label;
  final String dbRole;
  /// true = MANAGER terikat cabang (Kepala Cabang).
  final bool managerWithBranch;
}

class _UsersPageState extends ConsumerState<UsersPage> {
  static const _globalRoleChips = [
    _RoleChipDef(key: 'OWNER', label: 'Owner', dbRole: 'OWNER'),
    _RoleChipDef(
      key: 'MANAGER_PUSAT',
      label: RoleLabels.managerCentral,
      dbRole: 'MANAGER',
    ),
  ];

  static const _branchRoleChips = [
    _RoleChipDef(
      key: 'MANAGER_CABANG',
      label: RoleLabels.managerBranch,
      dbRole: 'MANAGER',
      managerWithBranch: true,
    ),
    _RoleChipDef(key: 'PHARMACIST', label: 'Apoteker', dbRole: 'PHARMACIST'),
    _RoleChipDef(key: 'CASHIER', label: 'Kasir', dbRole: 'CASHIER'),
    _RoleChipDef(key: 'STAFF', label: 'Asisten', dbRole: 'STAFF'),
    _RoleChipDef(key: 'WAREHOUSE', label: 'Gudang', dbRole: 'WAREHOUSE'),
  ];

  bool _ownerInBranchAssignments(Map<String, dynamic> u) {
    final raw = u['branch_assignments'] ?? u['branchAssignments'];
    if (raw is! List) return false;
    for (final item in raw) {
      if (item is! Map) continue;
      final roles = item['roles'];
      if (roles is List && roles.any((r) => r.toString() == 'OWNER')) {
        return true;
      }
    }
    return false;
  }

  Set<String> _globalRolesFromUser(Map<String, dynamic> u) {
    final raw = u['global_roles'] ?? u['globalRoles'];
    final globals = raw is List && raw.isNotEmpty
        ? raw.map((e) => e.toString()).toSet()
        : _parseRoles(u).where((r) => r == 'OWNER' || r == 'MANAGER').toSet();
    if (!globals.contains('OWNER') && _ownerInBranchAssignments(u)) {
      return {...globals, 'OWNER'};
    }
    return globals;
  }

  Map<String, Set<String>> _branchRolesMapFromUser(Map<String, dynamic> u) {
    final raw = u['branch_assignments'] ?? u['branchAssignments'];
    if (raw is List && raw.isNotEmpty) {
      final map = <String, Set<String>>{};
      for (final item in raw) {
        if (item is! Map) continue;
        final id = item['branch_id']?.toString() ??
            (item['branch'] as Map?)?['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final roles = item['roles'];
        final set = roles is List
            ? roles.map((e) => e.toString()).where((r) => r != 'OWNER').toSet()
            : <String>{};
        map[id] = set;
      }
      return map;
    }
    final branchIds = _branchIdsFromUser(u);
    final roles = _parseRoles(u)
        .where((r) => r != 'OWNER')
        .toSet();
    if (branchIds.isEmpty || roles.isEmpty) return {};
    return {for (final id in branchIds) id: Set<String>.from(roles)};
  }

  List<String> _branchIdsFromUser(Map<String, dynamic> u) {
    final assignments = u['branch_assignments'] ?? u['branchAssignments'];
    if (assignments is List && assignments.isNotEmpty) {
      return assignments
          .map((a) => (a as Map)['branch_id']?.toString())
          .whereType<String>()
          .toList();
    }
    final branches = u['branches'];
    if (branches is List && branches.isNotEmpty) {
      return branches
          .map((b) => (b as Map)['id']?.toString())
          .whereType<String>()
          .toList();
    }
    final direct = u['branchId']?.toString() ?? u['branch_id']?.toString();
    if (direct != null && direct.isNotEmpty) return [direct];
    return [];
  }

  String? _assignmentSummary(Map<String, dynamic> u) {
    final assignments = u['branch_assignments'] ?? u['branchAssignments'];
    if (assignments is List && assignments.isNotEmpty) {
      return assignments.map((item) {
        if (item is! Map) return '';
        final name =
            (item['branch'] as Map?)?['name']?.toString() ?? 'Cabang';
        final roles = (item['roles'] as List?)
                ?.map((r) => RoleLabels.labelFromMap(u, r.toString()))
                .join(', ') ??
            '';
        return '$name: $roles';
      }).where((s) => s.isNotEmpty).join(' · ');
    }
    final branch = (u['branch'] as Map?)?['name']?.toString();
    final roles = _parseRoles(u).map((r) => RoleLabels.labelFromMap(u, r)).join(', ');
    if (branch != null) return '$branch: $roles';
    return roles.isNotEmpty ? roles : null;
  }

  List<Map<String, dynamic>> _buildBranchAssignments(
    Map<String, Set<String>> branchRoles,
  ) {
    return branchRoles.entries
        .map(
          (e) => MapEntry(
            e.key,
            e.value.where((r) => r != 'OWNER').toSet(),
          ),
        )
        .where((e) => e.value.isNotEmpty)
        .map(
          (e) => {
            'branch_id': e.key,
            'roles': e.value.toList(),
          },
        )
        .toList();
  }

  Set<String> _sanitizeGlobalRoles(
    Set<String> globalRoles,
    Map<String, Set<String>> branchRoles,
  ) {
    final globals = Set<String>.from(globalRoles);
    for (final roles in branchRoles.values) {
      if (roles.contains('OWNER')) globals.add('OWNER');
    }
    return globals;
  }

  String? _validateAssignments(
    Set<String> globalRoles,
    Map<String, Set<String>> branchRoles,
  ) {
    final hasGlobal = globalRoles.isNotEmpty;
    final hasBranch = branchRoles.values.any((r) => r.isNotEmpty);
    if (!hasGlobal && !hasBranch) {
      return 'Pilih peran global atau penugasan cabang';
    }
    for (final entry in branchRoles.entries) {
      if (entry.value.contains('OWNER')) {
        return 'Owner hanya boleh di peran tenant — centang di bagian atas';
      }
      if (entry.value.isEmpty) {
        return 'Setiap cabang wajib memiliki minimal satu peran';
      }
    }
    return null;
  }

  Widget _globalRolesSection({
    required Set<String> selected,
    required void Function(Set<String>) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Peran tenant (opsional)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Owner & Manajer Pusat berlaku di seluruh tenant.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _globalRoleChips.map((chip) {
            final on = selected.contains(chip.dbRole);
            return FilterChip(
              label: Text(chip.label),
              selected: on,
              onSelected: (v) {
                final next = Set<String>.from(selected);
                if (v) {
                  next.add(chip.dbRole);
                } else {
                  next.remove(chip.dbRole);
                }
                onChanged(next);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _branchRoleChipsFor({
    required String branchName,
    required Set<String> selected,
    required void Function(Set<String>) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(branchName, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _branchRoleChips.map((chip) {
            final on = chip.dbRole == 'MANAGER'
                ? selected.contains('MANAGER')
                : selected.contains(chip.dbRole);
            return FilterChip(
              label: Text(chip.label),
              selected: on,
              onSelected: (v) {
                final next = Set<String>.from(selected);
                if (v) {
                  next.add(chip.dbRole);
                } else if (next.length > 1) {
                  next.remove(chip.dbRole);
                }
                onChanged(next);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _branchMultiSelect({
    required List<Map<String, dynamic>> branches,
    required Set<String> selectedIds,
    required void Function(Set<String>) onChanged,
    required String? primaryBranchId,
    required void Function(String?) onPrimaryChanged,
    required Map<String, Set<String>> branchRoles,
    required void Function(Map<String, Set<String>>) onBranchRolesChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Penugasan cabang',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Pilih cabang lalu tentukan peran di masing-masing cabang.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: branches.map((b) {
            final id = b['id']?.toString() ?? '';
            final name = b['name']?.toString() ?? '-';
            final on = selectedIds.contains(id);
            return FilterChip(
              label: Text(name),
              selected: on,
              onSelected: (v) {
                final next = Set<String>.from(selectedIds);
                final nextRoles = Map<String, Set<String>>.from(branchRoles);
                if (v) {
                  next.add(id);
                  nextRoles.putIfAbsent(id, () => {'STAFF'});
                } else {
                  next.remove(id);
                  nextRoles.remove(id);
                }
                onChanged(next);
                onBranchRolesChanged(nextRoles);
                if (next.isEmpty) {
                  onPrimaryChanged(null);
                } else if (primaryBranchId == null ||
                    !next.contains(primaryBranchId)) {
                  onPrimaryChanged(next.first);
                }
              },
            );
          }).toList(),
        ),
        if (selectedIds.length > 1) ...[
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: primaryBranchId != null && selectedIds.contains(primaryBranchId)
                ? primaryBranchId
                : selectedIds.first,
            decoration: const InputDecoration(labelText: 'Cabang utama (sesi aktif)'),
            items: selectedIds
                .map((id) {
                  final branch = branches.firstWhere(
                    (b) => b['id']?.toString() == id,
                    orElse: () => {'name': id},
                  );
                  return DropdownMenuItem(
                    value: id,
                    child: Text(branch['name']?.toString() ?? id),
                  );
                })
                .toList(),
            onChanged: onPrimaryChanged,
          ),
        ],
        ...selectedIds.map((id) {
          final branch = branches.firstWhere(
            (b) => b['id']?.toString() == id,
            orElse: () => {'name': id},
          );
          final name = branch['name']?.toString() ?? id;
          final roles = branchRoles[id] ?? {};
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: _branchRoleChipsFor(
              branchName: name,
              selected: roles,
              onChanged: (v) {
                final next = Map<String, Set<String>>.from(branchRoles);
                next[id] = v;
                onBranchRolesChanged(next);
              },
            ),
          );
        }),
      ],
    );
  }

  String _err(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message']?.toString();
        final errs = data['errors'];
        if (errs is List && errs.isNotEmpty) {
          return '${msg ?? 'Error'}: ${errs.join(', ')}';
        }
        if (msg != null && msg.isNotEmpty) return msg;
      }
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  List<String> _parseRoles(Map<String, dynamic> u) {
    final raw = u['roles'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    final single = u['role']?.toString();
    return single != null && single.isNotEmpty ? [single] : ['STAFF'];
  }

  String _rolesLabel(Map<String, dynamic> u) {
    final summary = _assignmentSummary(u);
    final active = u['role']?.toString();
    if (summary == null || summary.isEmpty) {
      return active != null ? RoleLabels.labelFromMap(u, active) : '-';
    }
    return active != null
        ? '$summary · aktif: ${RoleLabels.labelFromMap(u, active)}'
        : summary;
  }

  bool _isUserActive(Map<String, dynamic> u) {
    final v = u['isActive'] ?? u['is_active'];
    if (v is bool) return v;
    if (v == null) return true;
    return v.toString() != 'false' && v.toString() != '0';
  }

  Future<void> _openCreate() async {
    final fullNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    var globalRoles = <String>{};
    var selectedBranchIds = <String>{};
    var branchRoles = <String, Set<String>>{};
    String? primaryBranchId;

    if (!mounted) return;
    final branches = await ref.read(_branchesProviderForUsers.future);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Tambah User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fullNameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama lengkap'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                _globalRolesSection(
                  selected: globalRoles,
                  onChanged: (v) => setLocal(() => globalRoles = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                _branchMultiSelect(
                  branches: branches,
                  selectedIds: selectedBranchIds,
                  onChanged: (v) => setLocal(() => selectedBranchIds = v),
                  primaryBranchId: primaryBranchId,
                  onPrimaryChanged: (v) => setLocal(() => primaryBranchId = v),
                  branchRoles: branchRoles,
                  onBranchRolesChanged: (v) => setLocal(() => branchRoles = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Telepon (opsional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final fullName = fullNameCtrl.text.trim();
                  final email = emailCtrl.text.trim();
                  final password = passwordCtrl.text;
                  if (fullName.isEmpty || email.isEmpty || !email.contains('@')) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nama & email wajib diisi'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                    return;
                  }
                  if (password.length < 6) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password minimal 6 karakter'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                    return;
                  }
                  final roleErr = _validateAssignments(globalRoles, branchRoles);
                  if (roleErr != null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(roleErr),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                    return;
                  }
                  final assignments = _buildBranchAssignments(branchRoles);
                  final globals = _sanitizeGlobalRoles(globalRoles, branchRoles);
                  final primary = primaryBranchId ??
                      (selectedBranchIds.isNotEmpty
                          ? selectedBranchIds.first
                          : null);
                  final firstRole = globals.firstOrNull ??
                      branchRoles.values
                          .expand((r) => r)
                          .firstOrNull;
                  await ref.read(adminRepositoryProvider).createUser(
                        fullName: fullName,
                        email: email,
                        password: password,
                        globalRoles: globals.toList(),
                        branchAssignments: assignments,
                        activeRole: firstRole,
                        branchId: primary,
                        phone: phoneCtrl.text.trim(),
                      );
                  ref.invalidate(_usersProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('User berhasil dibuat'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_err(e)), backgroundColor: AppColors.danger),
                    );
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPasswordDialog(Map<String, dynamic> u) async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final name = (u['fullName'] ?? u['full_name'] ?? u['email']).toString();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ganti password\n$name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordCtrl,
              decoration: const InputDecoration(labelText: 'Password baru'),
              obscureText: true,
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: confirmCtrl,
              decoration: const InputDecoration(labelText: 'Konfirmasi password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final password = passwordCtrl.text;
              final confirm = confirmCtrl.text;
              if (password.length < 6) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password minimal 6 karakter'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
                return;
              }
              if (password != confirm) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Konfirmasi password tidak cocok'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
                return;
              }
              try {
                await ref.read(adminRepositoryProvider).resetUserPassword(
                      userId: u['id'] as String,
                      newPassword: password,
                    );
                ref.invalidate(_usersProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password berhasil diperbarui'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_err(e)), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(Map<String, dynamic> u) async {
    final name = (u['fullName'] ?? u['full_name'] ?? u['email']).toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus user?'),
        content: Text(
          'User $name akan dinonaktifkan dan tidak dapat login. '
          'Data tetap tersimpan dan dapat diaktifkan kembali.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(adminRepositoryProvider).deleteUser(u['id'] as String);
      ref.invalidate(_usersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User dihapus'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_err(e)), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _reactivateUser(Map<String, dynamic> u) async {
    final name = (u['fullName'] ?? u['full_name'] ?? u['email']).toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aktifkan user?'),
        content: Text('User $name akan dapat login kembali.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aktifkan'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(adminRepositoryProvider).updateUser(
            userId: u['id'] as String,
            isActive: true,
          );
      ref.invalidate(_usersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User diaktifkan'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_err(e)), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _openRoleDialog(Map<String, dynamic> u) async {
    if (!mounted) return;
    final branches = await ref.read(_branchesProviderForUsers.future);
    if (!mounted) return;
    var globalRoles = _globalRolesFromUser(u);
    var branchRoles = _branchRolesMapFromUser(u);
    var selectedBranchIds = branchRoles.keys.toSet();
    String? primaryBranchId = u['branchId']?.toString() ??
        u['branch_id']?.toString() ??
        (u['branch'] as Map?)?['id']?.toString();
    if (primaryBranchId == null && selectedBranchIds.isNotEmpty) {
      primaryBranchId = selectedBranchIds.first;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Ubah User\n${u['fullName'] ?? u['full_name'] ?? u['email']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _globalRolesSection(
                  selected: globalRoles,
                  onChanged: (v) => setLocal(() => globalRoles = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                _branchMultiSelect(
                  branches: branches,
                  selectedIds: selectedBranchIds,
                  onChanged: (v) => setLocal(() => selectedBranchIds = v),
                  primaryBranchId: primaryBranchId,
                  onPrimaryChanged: (v) => setLocal(() => primaryBranchId = v),
                  branchRoles: branchRoles,
                  onBranchRolesChanged: (v) => setLocal(() => branchRoles = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final roleErr = _validateAssignments(globalRoles, branchRoles);
                  if (roleErr != null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(roleErr),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                    return;
                  }
                  final assignments = _buildBranchAssignments(branchRoles);
                  final globals = _sanitizeGlobalRoles(globalRoles, branchRoles);
                  final primary = primaryBranchId ??
                      (selectedBranchIds.isNotEmpty
                          ? selectedBranchIds.first
                          : null);
                  await ref.read(adminRepositoryProvider).updateUser(
                        userId: u['id'] as String,
                        globalRoles: globals.toList(),
                        branchAssignments: assignments,
                        branchId: primary,
                      );
                  ref.invalidate(_usersProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_err(e)), backgroundColor: AppColors.danger),
                    );
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null || !user.canManageUsers) {
      return const AppScaffold(
        title: 'Kelola User',
        body: Center(
          child: Text('Hanya owner atau manajer pusat yang dapat mengelola user'),
        ),
      );
    }

    final async = ref.watch(_usersProvider);
    return AppScaffold(
      title: 'Kelola User',
      actions: [
        IconButton(onPressed: _openCreate, icon: const Icon(Icons.add)),
      ],
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(_err(e))),
        data: (result) {
          final items = result.items;
          if (items.isEmpty) return const Center(child: Text('Belum ada user'));
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index == items.length) {
                return PaginationBar(
                  meta: result.meta,
                  onPageChanged: (p) =>
                      ref.read(_usersPageProvider.notifier).state = p,
                );
              }
              final u = items[index];
              final name = (u['fullName'] ?? u['full_name'] ?? u['email']).toString();
              final email = (u['email'] ?? '').toString();
              final assignmentLine = _assignmentSummary(u);
              final isActive = _isUserActive(u);
              final currentUserId = ref.read(authProvider).user?.id;
              final isSelf = currentUserId != null && u['id']?.toString() == currentUserId;

              return Card(
                color: isActive ? null : AppColors.background,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.border,
                    child: Icon(
                      isActive ? Icons.person : Icons.person_off_outlined,
                      color: isActive ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            color: isActive ? null : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isActive ? AppColors.success : AppColors.danger)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isActive ? 'Aktif' : 'Nonaktif',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isActive ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email),
                      if (assignmentLine != null && assignmentLine.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          assignmentLine,
                          style: const TextStyle(fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        _rolesLabel(u),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      switch (action) {
                        case 'edit':
                          _openRoleDialog(u);
                        case 'password':
                          _openPasswordDialog(u);
                        case 'delete':
                          if (!isSelf && isActive) _deleteUser(u);
                        case 'reactivate':
                          if (!isSelf && !isActive) _reactivateUser(u);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.badge_outlined),
                          title: Text('Ubah role & cabang'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'password',
                        child: ListTile(
                          leading: Icon(Icons.lock_reset),
                          title: Text('Ganti password'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (isActive)
                        PopupMenuItem(
                          value: 'delete',
                          enabled: !isSelf,
                          child: ListTile(
                            leading: Icon(
                              Icons.delete_outline,
                              color: isSelf ? AppColors.textSecondary : AppColors.danger,
                            ),
                            title: const Text('Hapus'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        )
                      else
                        PopupMenuItem(
                          value: 'reactivate',
                          enabled: !isSelf,
                          child: ListTile(
                            leading: Icon(
                              Icons.check_circle_outline,
                              color: isSelf ? AppColors.textSecondary : null,
                            ),
                            title: const Text('Aktifkan'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                  onTap: () => _openRoleDialog(u),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        label: const Text('Tambah User'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
