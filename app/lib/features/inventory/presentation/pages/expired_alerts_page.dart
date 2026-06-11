import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../../shared/widgets/async_error_view.dart';
import '../../../../shared/widgets/async_loading_view.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../../reports/data/reports_repository.dart';
import '../../../reports/domain/entities/report_models.dart';

final _expiredAlertsProvider =
    FutureProvider.autoDispose<List<ExpiredRow>>((ref) async {
  return ref.watch(reportsRepositoryProvider).expired();
});

class ExpiredAlertsPage extends ConsumerWidget {
  const ExpiredAlertsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_expiredAlertsProvider);

    return AppScaffold(
      title: 'Alert Kadaluarsa',
      actions: [
        IconButton(
          tooltip: 'Laporan lengkap',
          icon: const Icon(Icons.bar_chart_outlined),
          onPressed: () => context.go('/reports'),
        ),
        IconButton(
          tooltip: 'Muat ulang',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(_expiredAlertsProvider),
        ),
      ],
      body: async.when(
        loading: () => const AsyncLoadingView(message: 'Memuat batch kadaluarsa…'),
        error: (e, _) => AsyncErrorView.fromError(
          e,
          onRetry: () => ref.invalidate(_expiredAlertsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyStateView(
              title: 'Tidak ada batch kadaluarsa',
              subtitle: 'Semua batch masih dalam masa berlaku.',
              icon: Icons.verified_outlined,
            );
          }

          final expired = items.where((r) => _isPast(r.expiredDate)).length;
          final soon = items.length - expired;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_expiredAlertsProvider);
              await ref.read(_expiredAlertsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        _alertChip(
                          label: 'Sudah expired',
                          count: expired,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _alertChip(
                          label: 'Perlu perhatian',
                          count: soon,
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...items.map((row) => _ExpiredAlertTile(row: row)),
              ],
            ),
          );
        },
      ),
    );
  }

  static bool _isPast(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return false;
    final today = DateTime.now();
    final d = DateTime(dt.year, dt.month, dt.day);
    final t = DateTime(today.year, today.month, today.day);
    return !d.isAfter(t);
  }

  static Widget _alertChip({
    required String label,
    required int count,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: color)),
            Text(
              '$count batch',
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiredAlertTile extends StatelessWidget {
  const _ExpiredAlertTile({required this.row});

  final ExpiredRow row;

  @override
  Widget build(BuildContext context) {
    final past = ExpiredAlertsPage._isPast(row.expiredDate);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: AppIcon3D.list(
          icon: past ? Icons.event_busy : Icons.schedule,
          accentKey: row.medicineName,
          accent: past ? AppColors.danger : AppColors.warning,
        ),
        title: Text(
          row.medicineName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Batch ${row.batchNumber} · Exp ${row.expiredDate}',
        ),
        trailing: Text(
          'Qty ${row.quantity}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: past ? AppColors.danger : AppColors.warning,
          ),
        ),
      ),
    );
  }
}
