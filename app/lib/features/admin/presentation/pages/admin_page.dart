import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_nav_list_tile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final canAdmin = user?.isOwner == true || user?.isManager == true;
    final canManageBranches = user?.isTenantWideManager == true;
    final canManageUsers = user?.canManageUsers == true;

    if (!canAdmin && !canManageBranches) {
      return const AppScaffold(
        title: 'Admin',
        body: Center(child: Text('Akses ditolak')),
      );
    }

    return AppScaffold(
      title: 'Admin',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (canManageBranches) ...[
            AppNavListTile(
              icon: Icons.store,
              title: 'Daftar Cabang',
              subtitle: 'Lihat cabang tenant (kelola via Super Admin)',
              onTap: () => context.push('/admin/branches'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (canManageUsers) ...[
            AppNavListTile(
              icon: Icons.people_outline,
              title: 'Kelola User',
              subtitle: 'List + tambah + ubah role',
              onTap: () => context.push('/admin/users'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (canAdmin) ...[
            AppNavListTile(
              icon: Icons.groups_outlined,
              title: 'Data Pelanggan',
              subtitle: 'Master pelanggan per apotik (tenant)',
              onTap: () => context.push('/customers'),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppNavListTile(
              icon: Icons.fact_check_outlined,
              title: 'Stock Opname',
              subtitle: 'Opname & transfer stok per cabang',
              onTap: () => context.go('/warehouse'),
            ),
          ],
        ],
      ),
    );
  }
}
