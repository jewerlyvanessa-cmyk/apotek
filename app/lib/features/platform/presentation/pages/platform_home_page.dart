import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/components/quick_menu_grid.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../license/presentation/providers/license_provider.dart';
class PlatformHomePage extends ConsumerWidget {
  const PlatformHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final licenseAsync = ref.watch(licenseStatusProvider);
    final isOnPrem = licenseAsync.maybeWhen(
      data: (s) => s.isOnPrem,
      orElse: () => false,
    );
    final showDbSetup = licenseAsync.maybeWhen(
      data: (s) =>
          s.isOnPrem && (s.installationType == 'perpetual' || !s.isOperational),
      orElse: () => false,
    );

    return AppScaffold(
      title: 'Platform Admin',
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    AppIcon3D.avatar(
                      icon: Icons.shield_outlined,
                      accent: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hai, ${user?.name ?? 'Super Admin'}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? 'Super Admin · Platform',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Menu cepat',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            QuickMenuGrid(
              items: [
                if (isOnPrem && showDbSetup)
                  QuickMenuItem(
                    icon: Icons.route_outlined,
                    title: 'Wizard Setup',
                    onTap: () => context.push('/platform/wizard'),
                  ),
                QuickMenuItem(
                  icon: Icons.apartment_outlined,
                  title: 'Kelola Tenant',
                  onTap: () => context.push('/platform/tenants'),
                ),
                QuickMenuItem(
                  icon: Icons.store_outlined,
                  title: 'Kelola Cabang',
                  onTap: () => context.push('/platform/branches'),
                ),
                QuickMenuItem(
                  icon: Icons.backup_outlined,
                  title: 'Backup Lokal',
                  onTap: () => context.push('/platform/backup'),
                ),
                QuickMenuItem(
                  icon: Icons.vpn_key_outlined,
                  title: 'Buat Lisensi',
                  onTap: () => context.push('/platform/license'),
                ),
                if (isOnPrem)
                  QuickMenuItem(
                    icon: Icons.dns_outlined,
                    title: 'Alamat Server API',
                    onTap: () => context.push('/platform/server'),
                  ),
                if (showDbSetup)
                  QuickMenuItem(
                    icon: Icons.storage_outlined,
                    title: 'Database On-Prem',
                    onTap: () => context.push('/platform/database'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
