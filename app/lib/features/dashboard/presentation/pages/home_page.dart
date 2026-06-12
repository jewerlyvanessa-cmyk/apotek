import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/offline/offline_providers.dart';
import '../../../../shared/components/quick_menu_grid.dart';
import '../../../../shared/widgets/app_icon_3d.dart';
import '../../../../shared/layouts/app_scaffold.dart';
import '../../../../shared/utils/currency_formatter.dart';
import '../../../../shared/widgets/async_error_view.dart';
import '../../../../shared/widgets/async_loading_view.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../../../shared/utils/role_labels.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/session_context_picker_dialog.dart';
import '../../../license/presentation/widgets/license_status_banner.dart';
import '../../../order/domain/entities/order.dart';
import '../../../order/presentation/providers/order_list_provider.dart';
import '../../../order/presentation/utils/order_status_ui.dart';
import '../../../payment/domain/entities/payment_summary.dart';
import '../../../payment/presentation/providers/payment_providers.dart';
import '../../../reports/data/reports_repository.dart';
import '../../../reports/domain/entities/report_models.dart';
import '../../../inventory/presentation/providers/stock_provider.dart';
import '../widgets/home_quick_menu.dart';

part '../widgets/home_dashboard_widgets.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final isTenantWide = user.isTenantWideManager;
    final isBranchManager = user.isBranchManager;
    final pendingCount = ref.watch(pendingActionsCountProvider);
    final branchModesAsync = ref.watch(branchStockModesProvider);
    final showEtalaseMenus = branchModesAsync.maybeWhen(
      data: (modes) => showWarehouseEtalaseMenus(user, modes),
      orElse: () => false,
    );
    final branchCountAsync = ref.watch(tenantActiveBranchCountProvider);
    final showMultiBranchMenus = branchCountAsync.maybeWhen(
      data: (count) => showMultiBranchWarehouseMenus(count),
      orElse: () => true,
    );
    return AppScaffold(
      title: user.contextTitle,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ListView(
          children: [
            const LicenseStatusBanner(),
            _ProfileSummaryCard(user: user),
            if (pendingCount > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: ListTile(
                  leading: AppIcon3D.list(
                    icon: Icons.cloud_upload_outlined,
                    accent: AppColors.primary,
                  ),
                  title: Text('Pending sync: $pendingCount'),
                  subtitle: const Text('Ada aksi yang tersimpan saat offline'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/pending-actions'),
                ),
              ),
            ],
            if (user.isStaff) ...[
              const SizedBox(height: AppSpacing.md),
              const _StaffTodayOrdersSummaryCard(),
            ],
            if (user.isCashier) ...[
              const SizedBox(height: AppSpacing.md),
              const _CashierTodayPaymentSummaryCard(),
            ],
            if (user.isPharmacist) ...[
              const SizedBox(height: AppSpacing.md),
              const _PharmacistTodayReviewsSummaryCard(),
            ],
            const SizedBox(height: AppSpacing.md),
            QuickMenuGrid(
              items: homeQuickMenuItems(
                context,
                user,
                showWarehouseEtalaseMenus: showEtalaseMenus,
                showMultiBranchMenus: showMultiBranchMenus,
              ),
            ),
            if (user.isStaff) ...[
              const SizedBox(height: AppSpacing.md),
              const _StaffTodayOrdersListCard(),
            ],
            if (user.isCashier) ...[
              const SizedBox(height: AppSpacing.md),
              const _CashierWaitingOrdersCard(),
            ],
            if (user.isPharmacist) ...[
              const SizedBox(height: AppSpacing.md),
              const _PharmacistPendingReviewsListCard(),
            ],
            if (isTenantWide || isBranchManager) ...[
              const SizedBox(height: AppSpacing.md),
              const _OwnerSummaryCards(),
              const SizedBox(height: AppSpacing.md),
              const _TopMedicinesCard(),
              const SizedBox(height: AppSpacing.md),
              const _LowStockCard(),
            ],
          ],
        ),
      ),
    );
  }
}
