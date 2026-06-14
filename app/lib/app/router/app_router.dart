import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/change_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/cashier/presentation/pages/cashier_page.dart';
import '../../features/cashier/presentation/pages/cashier_order_page.dart';
import '../../features/cashier/presentation/pages/cashier_pay_page.dart';
import '../../features/cashier/presentation/pages/cashier_ledger_page.dart';
import '../../features/dashboard/presentation/pages/home_page.dart';
import '../../features/inventory/presentation/pages/stock_list_page.dart';
import '../../features/inventory/presentation/pages/expired_alerts_page.dart';
import '../../features/search/presentation/pages/global_search_page.dart';
import '../../features/medicine/presentation/pages/catalog_master_page.dart';
import '../../features/medicine/presentation/pages/medicine_form_page.dart';
import '../../features/medicine/presentation/pages/medicine_list_page.dart';
import '../../features/order/presentation/pages/create_order_page.dart';
import '../../features/order/presentation/pages/order_detail_page.dart';
import '../../features/payment/presentation/pages/payment_detail_page.dart';
import '../../features/offline/presentation/pages/pending_actions_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/reports/presentation/pages/cashier_branch_report_page.dart';
import '../../features/reports/presentation/pages/staff_branch_report_page.dart';
import '../../features/reports/presentation/pages/branch_report_page.dart';
import '../../features/pharmacy/presentation/pages/pharmacy_reviews_page.dart';
import '../../features/warehouse/presentation/pages/warehouse_page.dart';
import '../../features/procurement/presentation/pages/procurement_page.dart';
import '../../features/procurement/presentation/pages/create_procurement_page.dart';
import '../../features/distribution/presentation/pages/distribution_page.dart';
import '../../features/inventory/presentation/pages/central_stock_page.dart';
import '../../features/admin/presentation/pages/admin_page.dart';
import '../../features/backup/presentation/pages/manager_backup_page.dart';
import '../../features/license/presentation/pages/activate_license_page.dart';
import '../../features/license/presentation/pages/tenant_license_status_page.dart';
import '../../features/platform/presentation/pages/platform_home_page.dart';
import '../../features/platform/presentation/pages/platform_backup_page.dart';
import '../../features/platform/presentation/pages/platform_license_page.dart';
import '../../features/platform/presentation/pages/tenants_list_page.dart';
import '../../features/platform/presentation/pages/tenant_form_page.dart';
import '../../features/platform/presentation/pages/platform_branches_page.dart';
import '../../features/platform/presentation/pages/platform_branches_hub_page.dart';
import '../../features/admin/presentation/pages/branches_page.dart';
import '../../features/admin/presentation/pages/branch_stock_mode_page.dart';
import '../../features/inventory/presentation/pages/replenish_stock_page.dart';
import '../../features/admin/presentation/pages/users_page.dart';
import '../../features/customer/presentation/pages/customers_page.dart';
import '../../features/customer/presentation/pages/customer_detail_page.dart';
import '../../features/warehouse/presentation/pages/opname_page.dart';
import '../../features/warehouse/presentation/pages/transfer_page.dart';
import '../../features/setup/presentation/pages/database_setup_page.dart';
import '../../features/setup/presentation/pages/on_prem_wizard_page.dart';
import '../../features/setup/presentation/pages/server_setup_page.dart';
import '../../features/setup/presentation/pages/printer_settings_page.dart';
import '../../shared/layouts/app_scaffold.dart';
import '../../features/inventory/presentation/pages/stock_movements_page.dart';
import '../../features/inventory/presentation/pages/receive_stock_page.dart';
import '../../shared/pages/barcode_scanner_page.dart';
import '../../features/notifications/presentation/pages/notification_center_page.dart';
import '../../core/auth/route_access.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  final user = auth.user;
  final role = user?.role;
  /// Peran aktif sesi — untuk rute yang bergantung peran utama (Owner, Manajer, dll.).
  bool hasActive(String r) => role == r;
  /// Peran ditugaskan di cabang — Staff/Kasir bisa dipakai bersamaan tanpa ganti peran.
  bool hasAssigned(String r) => user?.hasRoleInBranch(r) ?? false;
  bool has(String r) {
    if (r == 'STAFF' || r == 'CASHIER') return hasAssigned(r);
    return hasActive(r);
  }
  final isTenantWide = user?.isTenantWideManager ?? false;

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: auth.isAuthenticated
        ? (role == 'SUPER_ADMIN' ? '/platform' : '/home')
        : '/login',
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final onLogin = state.matchedLocation == '/login';
      final isSuperAdmin = role == 'SUPER_ADMIN';

      final onActivateLicense = state.matchedLocation == '/activate-license';
      final onChangePassword = state.matchedLocation == '/change-password';
      final onServerSetup = state.matchedLocation == '/platform/server';
      final onDatabaseSetup = state.matchedLocation == '/platform/database';
      final mustChangePassword = user?.mustChangePassword == true;

      if (!loggedIn && onChangePassword) {
        return '/login';
      }
      if (!loggedIn && !onLogin && !onActivateLicense && !onServerSetup) {
        return '/login';
      }
      if (loggedIn && mustChangePassword && !onChangePassword) {
        return '/change-password';
      }
      if (loggedIn && onChangePassword && !mustChangePassword) {
        return isSuperAdmin ? '/platform' : '/home';
      }
      if (loggedIn && !isSuperAdmin && onDatabaseSetup) {
        return '/home';
      }
      if (loggedIn && onLogin) {
        return isSuperAdmin ? '/platform' : '/home';
      }
      if (loggedIn &&
          isSuperAdmin &&
          !onChangePassword &&
          !state.matchedLocation.startsWith('/platform')) {
        return '/platform';
      }
      if (loggedIn &&
          !isSuperAdmin &&
          state.matchedLocation.startsWith('/platform') &&
          !onServerSetup) {
        return '/home';
      }
      if (loggedIn && user != null && !isSuperAdmin) {
        final loc = state.matchedLocation;
        if (user.isBranchManager && loc == '/reports') {
          return '/reports/branch';
        }
        if (!isRouteAllowedForActiveRole(loc, user)) {
          return '/home';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/activate-license',
        builder: (context, state) => const ActivateLicensePage(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: '/platform',
        builder: (context, state) => const PlatformHomePage(),
        routes: [
          GoRoute(
            path: 'wizard',
            builder: (context, state) => const OnPremWizardPage(),
          ),
          GoRoute(
            path: 'server',
            builder: (context, state) => const ServerSetupPage(),
          ),
          GoRoute(
            path: 'database',
            builder: (context, state) => const DatabaseSetupPage(),
          ),
          GoRoute(
            path: 'branches',
            builder: (context, state) => const PlatformBranchesHubPage(),
          ),
          GoRoute(
            path: 'tenants',
            builder: (context, state) => const TenantsListPage(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const TenantFormPage(),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (context, state) => TenantFormPage(
                  tenantId: state.pathParameters['id'],
                ),
              ),
              GoRoute(
                path: ':id/branches',
                builder: (context, state) => PlatformBranchesPage(
                  tenantId: state.pathParameters['id']!,
                  tenantName: state.uri.queryParameters['name'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'backup',
            builder: (context, state) => const PlatformBackupPage(),
          ),
          GoRoute(
            path: 'license',
            builder: (context, state) => const PlatformLicensePage(),
          ),
        ],
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      if (has('STAFF'))
        GoRoute(
          path: '/orders',
          builder: (context, state) => const CreateOrderPage(),
        ),
      if (role != 'SUPER_ADMIN' && role != null) ...[
        GoRoute(
          path: '/payments/:id',
          builder: (context, state) => PaymentDetailPage(
            paymentId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/orders/:id/edit',
          builder: (context, state) => CreateOrderPage(
            orderId: state.pathParameters['id'],
          ),
        ),
        GoRoute(
          path: '/orders/:id',
          builder: (context, state) => OrderDetailPage(
            orderId: state.pathParameters['id']!,
          ),
        ),
      ],
      if (has('CASHIER'))
        GoRoute(
          path: '/reports/cashier',
          builder: (context, state) => const CashierBranchReportPage(),
        ),
      if (has('STAFF') || has('PHARMACIST'))
        GoRoute(
          path: '/reports/staff',
          builder: (context, state) => const StaffBranchReportPage(),
        ),
      if (has('OWNER') || (has('MANAGER') && isTenantWide))
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsPage(),
        ),
      if (has('MANAGER') && (user?.isBranchManager ?? false))
        GoRoute(
          path: '/reports/branch',
          builder: (context, state) => const BranchReportPage(),
        ),
      if (has('PHARMACIST') || has('OWNER'))
        GoRoute(
          path: '/pharmacy/reviews',
          builder: (context, state) => const PharmacyReviewsPage(),
        ),
      if (has('CASHIER')) ...[
        GoRoute(
          path: '/cashier',
          builder: (context, state) => const CashierPage(),
          routes: [
            GoRoute(
              path: 'ledger',
              builder: (context, state) => const CashierLedgerPage(),
            ),
            GoRoute(
              path: 'orders/:id',
              builder: (context, state) => CashierOrderPage(
                orderId: state.pathParameters['id']!,
              ),
              routes: [
                GoRoute(
                  path: 'pay',
                  builder: (context, state) => CashierPayPage(
                    orderId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
      if (has('OWNER') || has('MANAGER')) ...[
        GoRoute(
          path: '/ledger',
          builder: (context, state) => const CashierLedgerPage(),
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminPage(),
          routes: [
            GoRoute(
              path: 'branches',
              builder: (context, state) => const BranchesPage(),
              routes: [
                GoRoute(
                  path: ':id/stock-mode',
                  builder: (context, state) {
                    final extra = state.extra;
                    final map = extra is Map<String, dynamic> ? extra : null;
                    return BranchStockModePage(
                      branchId: state.pathParameters['id']!,
                      branchName: map?['name']?.toString() ?? 'Cabang',
                      initialMode: map?['stock_mode']?.toString(),
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: 'users',
              builder: (context, state) => const UsersPage(),
            ),
          ],
        ),
        GoRoute(
          path: '/customers',
          builder: (context, state) => const CustomersPage(),
        ),
        GoRoute(
          path: '/customers/:id',
          builder: (context, state) => CustomerDetailPage(
            customerId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/backup',
          builder: (context, state) => const ManagerBackupPage(),
        ),
      ],
      if (has('OWNER'))
        GoRoute(
          path: '/license-status',
          builder: (context, state) => const TenantLicenseStatusPage(),
        ),
      if (has('OWNER') || has('MANAGER') || has('WAREHOUSE'))
        GoRoute(
          path: '/medicines',
          builder: (context, state) => const MedicineListPage(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const MedicineFormPage(),
            ),
            GoRoute(
              path: ':id/edit',
              builder: (context, state) => MedicineFormPage(
                medicineId: state.pathParameters['id'],
              ),
            ),
            GoRoute(
              path: 'master',
              builder: (context, state) => const CatalogMasterPage(),
            ),
          ],
        ),
      if (has('OWNER') || has('MANAGER') || has('WAREHOUSE'))
        GoRoute(
          path: '/warehouse',
          builder: (context, state) => const WarehousePage(),
          routes: [
            GoRoute(
              path: 'opname',
              builder: (context, state) => const AppScaffold(
                title: 'Stock Opname',
                body: OpnamePage(),
              ),
            ),
            GoRoute(
              path: 'transfer',
              builder: (context, state) => const AppScaffold(
                title: 'Transfer Stok',
                body: TransferPage(),
              ),
            ),
          ],
        ),
      if (has('OWNER') || (has('MANAGER') && isTenantWide)) ...[
        GoRoute(
          path: '/procurements',
          builder: (context, state) => const ProcurementPage(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const CreateProcurementPage(),
            ),
          ],
        ),
      ],
      if (has('OWNER') || has('MANAGER') || has('WAREHOUSE'))
        GoRoute(
          path: '/distributions',
          builder: (context, state) => const DistributionPage(),
        ),
      if (has('OWNER') || (has('MANAGER') && isTenantWide) || has('WAREHOUSE'))
        GoRoute(
          path: '/stocks/central',
          builder: (context, state) => const CentralStockPage(),
        ),
      if (role != 'SUPER_ADMIN' &&
          role != null &&
          !has('OWNER') &&
          !has('MANAGER') &&
          !has('STAFF') &&
          !has('CASHIER') &&
          !has('WAREHOUSE'))
        GoRoute(
          path: '/medicines',
          builder: (context, state) => const MedicineListPage(),
        ),
      if (role != 'SUPER_ADMIN' && role != null)
        GoRoute(
          path: '/stocks',
          builder: (context, state) => const StockListPage(),
        ),
      if (role != 'SUPER_ADMIN' && role != 'CASHIER' && role != null)
        GoRoute(
          path: '/alerts/expired',
          builder: (context, state) => const ExpiredAlertsPage(),
        ),
      if (role != 'SUPER_ADMIN' && role != null)
        GoRoute(
          path: '/search',
          builder: (context, state) => const GlobalSearchPage(),
        ),
      GoRoute(
        path: '/pending-actions',
        builder: (context, state) => const PendingActionsPage(),
      ),
      GoRoute(
        path: '/stock-movements',
        builder: (context, state) => const StockMovementsPage(),
      ),
      GoRoute(
        path: '/stocks/receive',
        builder: (context, state) => ReceiveStockPage(
          initialBranchId: state.extra as String?,
        ),
      ),
      if (has('OWNER') || has('MANAGER') || has('WAREHOUSE')) ...[
        GoRoute(
          path: '/stocks/replenish',
          builder: (context, state) => ReplenishStockPage(
            initialBranchId: state.extra as String?,
          ),
        ),
        GoRoute(
          path: '/stocks/locations/back',
          builder: (context, state) => const StockListPage(
            title: 'Stok Gudang Cabang',
            locationCode: 'BACK',
          ),
        ),
        GoRoute(
          path: '/stocks/locations/front',
          builder: (context, state) => const StockListPage(
            title: 'Stok Etalase',
            locationCode: 'FRONT',
            sellableOnly: true,
          ),
        ),
      ],
      GoRoute(
        path: '/scan',
        builder: (context, state) => const BarcodeScannerPage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationCenterPage(),
      ),
      if (role != 'SUPER_ADMIN' && role != null)
        GoRoute(
          path: '/settings/printer',
          builder: (context, state) => const PrinterSettingsPage(),
        ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Halaman tidak ditemukan: ${state.uri}')),
    ),
  );
});
