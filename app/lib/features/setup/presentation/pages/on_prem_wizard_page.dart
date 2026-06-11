import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/printing/printer_providers.dart';
import '../../../../core/storage/server_url_storage.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../license/presentation/providers/license_provider.dart';
import '../../../platform/data/platform_repository.dart';
import '../providers/setup_provider.dart';

final _wizardTenantsProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final result = await ref.watch(platformRepositoryProvider).listTenants(
        page: 1,
        limit: 1,
      );
  return result.meta.total;
});

class OnPremWizardPage extends ConsumerWidget {
  const OnPremWizardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setupAsync = ref.watch(setupStatusProvider);
    final licenseAsync = ref.watch(licenseStatusProvider);
    final tenantsAsync = ref.watch(_wizardTenantsProvider);
    final prefs = ref.watch(prefsProvider);
    final hasCustomServer =
        (ServerUrlStorage(prefs).savedApiBaseUrl ?? '').isNotEmpty;

    return AppScaffold(
      title: 'Setup On-Prem',
      body: setupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat status: $e')),
        data: (setup) {
          final dbOk =
              setup['database_configured'] == true &&
              setup['schema_ready'] == true;
          final licenseOk = setup['license_valid'] == true ||
              licenseAsync.maybeWhen(
                data: (l) => l.installationValid == true,
                orElse: () => false,
              );
          final tenantCount = tenantsAsync.maybeWhen(
            data: (c) => c,
            orElse: () => 0,
          );
          final tenantsOk = tenantCount > 0;

          final steps = [
            _WizardStep(
              title: 'Alamat server API',
              subtitle: 'Pastikan aplikasi terhubung ke backend on-prem',
              done: hasCustomServer,
              actionLabel: 'Atur server',
              route: '/platform/server',
            ),
            _WizardStep(
              title: 'Database PostgreSQL',
              subtitle: dbOk
                  ? 'Database terhubung & skema siap'
                  : setup['database_message']?.toString() ??
                      'Buat database dan jalankan migrasi',
              done: dbOk,
              actionLabel: 'Setup database',
              route: '/platform/database',
            ),
            _WizardStep(
              title: 'Aktivasi lisensi',
              subtitle: licenseOk
                  ? 'Lisensi instalasi aktif'
                  : 'Generate & aktivasi lisensi beli putus',
              done: licenseOk,
              actionLabel: 'Kelola lisensi',
              route: '/platform/license',
            ),
            _WizardStep(
              title: 'Tenant & owner',
              subtitle: tenantsOk
                  ? '$tenantCount tenant terdaftar'
                  : 'Buat tenant pertama beserta akun owner',
              done: tenantsOk,
              actionLabel: 'Kelola tenant',
              route: '/platform/tenants',
            ),
          ];

          final completed = steps.where((s) => s.done).length;
          final allDone = completed == steps.length;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Card(
                color: allDone
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.primary.withValues(alpha: 0.06),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allDone
                            ? 'Setup on-prem selesai'
                            : 'Langkah $completed dari ${steps.length}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        allDone
                            ? 'Sistem siap digunakan. Owner dapat login ke tenant.'
                            : 'Ikuti langkah berurutan untuk instalasi beli putus.',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      LinearProgressIndicator(
                        value: completed / steps.length,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...steps.asMap().entries.map((entry) {
                final i = entry.key;
                final step = entry.value;
                return _StepCard(
                  index: i + 1,
                  step: step,
                  onAction: () => context.push(step.route),
                );
              }),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(setupStatusProvider);
                  ref.invalidate(licenseStatusProvider);
                  ref.invalidate(_wizardTenantsProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Periksa ulang status'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WizardStep {
  const _WizardStep({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.actionLabel,
    required this.route,
  });

  final String title;
  final String subtitle;
  final bool done;
  final String actionLabel;
  final String route;
}

IconData _stepNumberIcon(int index) {
  switch (index) {
    case 1:
      return Icons.looks_one_outlined;
    case 2:
      return Icons.looks_two_outlined;
    case 3:
      return Icons.looks_3_outlined;
    case 4:
      return Icons.looks_4_outlined;
    default:
      return Icons.circle_outlined;
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.index,
    required this.step,
    required this.onAction,
  });

  final int index;
  final _WizardStep step;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final color = step.done ? AppColors.success : AppColors.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                step.done ? Icons.check : _stepNumberIcon(index),
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: onAction,
                    child: Text(step.actionLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
