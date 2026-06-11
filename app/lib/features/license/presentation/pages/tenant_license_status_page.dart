import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../billing/presentation/widgets/saas_renewal_section.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../providers/license_provider.dart';

class TenantLicenseStatusPage extends ConsumerWidget {
  const TenantLicenseStatusPage({super.key});

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Selamanya';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  String _typeLabel(String? type) {
    if (type == 'subscription') return 'Berlangganan';
    if (type == 'perpetual') return 'Beli putus';
    return type ?? '—';
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(licenseStatusProvider);
    final user = ref.watch(authProvider).user;
    final canRenew =
        user != null && (user.isOwner || user.isManager);

    return AppScaffold(
      title: 'Status Lisensi',
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (status) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _section(
                context,
                title: 'Mode deployment',
                children: [
                  _infoRow(
                    'Mode',
                    status.isOnPrem ? 'On-prem (server Anda)' : 'SaaS',
                  ),
                ],
              ),
              if (status.isOnPrem) ...[
                const SizedBox(height: AppSpacing.lg),
                _section(
                  context,
                  title: 'Lisensi instalasi',
                  children: [
                    _infoRow(
                      'Status',
                      status.installationValid == true ? 'Aktif' : 'Belum aktif',
                      valueColor: status.installationValid == true
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                    if (status.installationCustomer != null)
                      _infoRow('Pelanggan', status.installationCustomer!),
                    if (status.installationType != null)
                      _infoRow('Tipe', _typeLabel(status.installationType)),
                    if (status.installationPlan != null)
                      _infoRow('Paket', status.installationPlan!),
                    if (status.installationMaxBranches != null)
                      _infoRow(
                        'Maks. cabang',
                        '${status.installationMaxBranches}',
                      ),
                    _infoRow(
                      'Berlaku hingga',
                      _fmtDate(status.installationExpiresAt),
                    ),
                  ],
                ),
              ],
              if (status.isSaas || status.tenantPlan != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _section(
                  context,
                  title: 'Langganan tenant',
                  children: [
                    _infoRow(
                      'Status',
                      status.tenantValid == true ? 'Aktif' : 'Tidak aktif',
                      valueColor: status.tenantValid == true
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                    if (status.tenantPlan != null)
                      _infoRow('Paket', status.tenantPlan!),
                    _infoRow(
                      'Berlaku hingga',
                      _fmtDate(status.tenantExpiresAt),
                    ),
                    if (status.tenantDaysRemaining != null)
                      _infoRow('Sisa hari', '${status.tenantDaysRemaining}'),
                    if (status.tenantInGracePeriod)
                      _infoRow('Catatan', 'Masa tenggang langganan'),
                  ],
                ),
              ],
              if (status.isSaas && canRenew) ...[
                const SizedBox(height: AppSpacing.lg),
                _section(
                  context,
                  title: 'Perpanjang langganan',
                  children: [
                    SaasRenewalSection(currentPlan: status.tenantPlan),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
