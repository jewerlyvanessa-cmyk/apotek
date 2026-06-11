import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/route_access.dart';
import '../../../../shared/components/quick_menu_grid.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../inventory/presentation/providers/stock_provider.dart';

List<QuickMenuItem> homeQuickMenuItems(
  BuildContext context,
  AuthUser user, {
  bool showWarehouseEtalaseMenus = false,
}) {
  final items = switch (user.role) {
    'OWNER' => _ownerMenus(context),
    'MANAGER' when user.isTenantWideManager => _tenantManagerMenus(context),
    'MANAGER' when user.isBranchManager => _branchManagerMenus(context),
    'MANAGER' => _branchManagerMenus(context),
    'PHARMACIST' => _pharmacistMenus(context),
    'WAREHOUSE' => _warehouseMenus(context, user),
    'STAFF' => _staffMenus(context),
    'CASHIER' => _cashierMenus(context),
    _ => const <_DashboardMenuEntry>[],
  };
  return items
      .where((item) => isRouteAllowedForActiveRole(item.path, user))
      .where(
        (item) =>
            showWarehouseEtalaseMenus ||
            !warehouseEtalaseMenuPaths.contains(item.path),
      )
      .map(
        (item) => QuickMenuItem(
          icon: item.icon,
          title: item.title,
          onTap: item.onTap,
        ),
      )
      .toList();
}

class _DashboardMenuEntry {
  const _DashboardMenuEntry({
    required this.path,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final String path;
  final IconData icon;
  final String title;
  final VoidCallback onTap;
}

List<_DashboardMenuEntry> _ownerMenus(BuildContext context) => [
      _DashboardMenuEntry(
        path: '/admin/branches',
        icon: Icons.store,
        title: 'Daftar Cabang',
        onTap: () => context.push('/admin/branches'),
      ),
      _DashboardMenuEntry(
        path: '/admin/users',
        icon: Icons.people_outline,
        title: 'Kelola User',
        onTap: () => context.push('/admin/users'),
      ),
      _DashboardMenuEntry(
        path: '/customers',
        icon: Icons.groups_outlined,
        title: 'Data Pelanggan',
        onTap: () => context.push('/customers'),
      ),
      _DashboardMenuEntry(
        path: '/reports',
        icon: Icons.bar_chart_outlined,
        title: 'Laporan',
        onTap: () => context.go('/reports'),
      ),
      _DashboardMenuEntry(
        path: '/ledger',
        icon: Icons.account_balance_wallet_outlined,
        title: 'Kas Cabang',
        onTap: () => context.go('/ledger'),
      ),
      _DashboardMenuEntry(
        path: '/stocks',
        icon: Icons.inventory_2_outlined,
        title: 'Stok Tenant',
        onTap: () => context.go('/stocks'),
      ),
      _DashboardMenuEntry(
        path: '/alerts/expired',
        icon: Icons.event_busy_outlined,
        title: 'Alert Kadaluarsa',
        onTap: () => context.push('/alerts/expired'),
      ),
      _DashboardMenuEntry(
        path: '/stocks/central',
        icon: Icons.warehouse_outlined,
        title: 'Stok Gudang Pusat',
        onTap: () => context.go('/stocks/central'),
      ),
      _DashboardMenuEntry(
        path: '/procurements',
        icon: Icons.local_shipping_outlined,
        title: 'Pengadaan',
        onTap: () => context.go('/procurements'),
      ),
      _DashboardMenuEntry(
        path: '/distributions',
        icon: Icons.call_split,
        title: 'Distribusi',
        onTap: () => context.go('/distributions'),
      ),
      _DashboardMenuEntry(
        path: '/medicines',
        icon: Icons.medication_outlined,
        title: 'Katalog Produk',
        onTap: () => context.go('/medicines'),
      ),
      _DashboardMenuEntry(
        path: '/pharmacy/reviews',
        icon: Icons.medical_services_outlined,
        title: 'Telaah Order',
        onTap: () => context.go('/pharmacy/reviews'),
      ),
      _DashboardMenuEntry(
        path: '/backup',
        icon: Icons.backup_outlined,
        title: 'Backup Lokal',
        onTap: () => context.go('/backup'),
      ),
      _DashboardMenuEntry(
        path: '/license-status',
        icon: Icons.verified_outlined,
        title: 'Status Lisensi',
        onTap: () => context.go('/license-status'),
      ),
      _DashboardMenuEntry(
        path: '/settings/printer',
        icon: Icons.print_outlined,
        title: 'Printer Thermal',
        onTap: () => context.push('/settings/printer'),
      ),
    ];

List<_DashboardMenuEntry> _tenantManagerMenus(BuildContext context) => [
      _DashboardMenuEntry(
        path: '/admin/branches',
        icon: Icons.store,
        title: 'Daftar Cabang',
        onTap: () => context.push('/admin/branches'),
      ),
      _DashboardMenuEntry(
        path: '/admin/users',
        icon: Icons.people_outline,
        title: 'Kelola User',
        onTap: () => context.push('/admin/users'),
      ),
      _DashboardMenuEntry(
        path: '/customers',
        icon: Icons.groups_outlined,
        title: 'Data Pelanggan',
        onTap: () => context.push('/customers'),
      ),
      _DashboardMenuEntry(
        path: '/reports',
        icon: Icons.bar_chart_outlined,
        title: 'Laporan',
        onTap: () => context.go('/reports'),
      ),
      _DashboardMenuEntry(
        path: '/ledger',
        icon: Icons.account_balance_wallet_outlined,
        title: 'Kas Cabang',
        onTap: () => context.go('/ledger'),
      ),
      _DashboardMenuEntry(
        path: '/stocks',
        icon: Icons.inventory_2_outlined,
        title: 'Stok Tenant',
        onTap: () => context.go('/stocks'),
      ),
      _DashboardMenuEntry(
        path: '/alerts/expired',
        icon: Icons.event_busy_outlined,
        title: 'Alert Kadaluarsa',
        onTap: () => context.push('/alerts/expired'),
      ),
      _DashboardMenuEntry(
        path: '/stocks/central',
        icon: Icons.warehouse_outlined,
        title: 'Stok Gudang Pusat',
        onTap: () => context.go('/stocks/central'),
      ),
      _DashboardMenuEntry(
        path: '/procurements',
        icon: Icons.local_shipping_outlined,
        title: 'Pengadaan',
        onTap: () => context.go('/procurements'),
      ),
      _DashboardMenuEntry(
        path: '/distributions',
        icon: Icons.call_split,
        title: 'Distribusi',
        onTap: () => context.go('/distributions'),
      ),
      _DashboardMenuEntry(
        path: '/medicines',
        icon: Icons.medication_outlined,
        title: 'Katalog Produk',
        onTap: () => context.go('/medicines'),
      ),
      _DashboardMenuEntry(
        path: '/backup',
        icon: Icons.backup_outlined,
        title: 'Backup Lokal',
        onTap: () => context.go('/backup'),
      ),
      _DashboardMenuEntry(
        path: '/settings/printer',
        icon: Icons.print_outlined,
        title: 'Printer Thermal',
        onTap: () => context.push('/settings/printer'),
      ),
    ];

List<_DashboardMenuEntry> _branchManagerMenus(BuildContext context) => [
      _DashboardMenuEntry(
        path: '/customers',
        icon: Icons.groups_outlined,
        title: 'Data Pelanggan',
        onTap: () => context.push('/customers'),
      ),
      _DashboardMenuEntry(
        path: '/reports/branch',
        icon: Icons.bar_chart_outlined,
        title: 'Laporan Cabang',
        onTap: () => context.go('/reports/branch'),
      ),
      _DashboardMenuEntry(
        path: '/ledger',
        icon: Icons.account_balance_wallet_outlined,
        title: 'Kas Cabang',
        onTap: () => context.go('/ledger'),
      ),
      _DashboardMenuEntry(
        path: '/stocks',
        icon: Icons.inventory_2_outlined,
        title: 'Stok Cabang',
        onTap: () => context.go('/stocks'),
      ),
      _DashboardMenuEntry(
        path: '/alerts/expired',
        icon: Icons.event_busy_outlined,
        title: 'Alert Kadaluarsa',
        onTap: () => context.push('/alerts/expired'),
      ),
      _DashboardMenuEntry(
        path: '/medicines',
        icon: Icons.medication_outlined,
        title: 'Katalog Produk',
        onTap: () => context.go('/medicines'),
      ),
      _DashboardMenuEntry(
        path: '/warehouse',
        icon: Icons.fact_check_outlined,
        title: 'Gudang & Opname',
        onTap: () => context.go('/warehouse'),
      ),
      _DashboardMenuEntry(
        path: '/stocks/locations/back',
        icon: Icons.warehouse_outlined,
        title: 'Gudang Cabang',
        onTap: () => context.go('/stocks/locations/back'),
      ),
      _DashboardMenuEntry(
        path: '/stocks/locations/front',
        icon: Icons.storefront_outlined,
        title: 'Stok Etalase',
        onTap: () => context.go('/stocks/locations/front'),
      ),
      _DashboardMenuEntry(
        path: '/stocks/replenish',
        icon: Icons.move_to_inbox_outlined,
        title: 'Isi Etalase',
        onTap: () => context.push('/stocks/replenish'),
      ),
      _DashboardMenuEntry(
        path: '/distributions',
        icon: Icons.call_split,
        title: 'Terima Distribusi',
        onTap: () => context.go('/distributions'),
      ),
      _DashboardMenuEntry(
        path: '/backup',
        icon: Icons.backup_outlined,
        title: 'Backup Lokal',
        onTap: () => context.go('/backup'),
      ),
      _DashboardMenuEntry(
        path: '/settings/printer',
        icon: Icons.print_outlined,
        title: 'Printer Thermal',
        onTap: () => context.push('/settings/printer'),
      ),
    ];

List<_DashboardMenuEntry> _pharmacistMenus(BuildContext context) => [
      _DashboardMenuEntry(
        path: '/pharmacy/reviews',
        icon: Icons.medical_services_outlined,
        title: 'Telaah Order',
        onTap: () => context.go('/pharmacy/reviews'),
      ),
      _DashboardMenuEntry(
        path: '/stocks',
        icon: Icons.inventory_2_outlined,
        title: 'Stok Cabang',
        onTap: () => context.go('/stocks'),
      ),
      _DashboardMenuEntry(
        path: '/alerts/expired',
        icon: Icons.event_busy_outlined,
        title: 'Alert Kadaluarsa',
        onTap: () => context.push('/alerts/expired'),
      ),
      _DashboardMenuEntry(
        path: '/medicines',
        icon: Icons.medication_outlined,
        title: 'Katalog Produk',
        onTap: () => context.go('/medicines'),
      ),
      _DashboardMenuEntry(
        path: '/reports/staff',
        icon: Icons.assignment_outlined,
        title: 'Laporan Order',
        onTap: () => context.go('/reports/staff'),
      ),
    ];

List<_DashboardMenuEntry> _warehouseMenus(
  BuildContext context,
  AuthUser user,
) =>
    [
      _DashboardMenuEntry(
        path: '/stocks',
        icon: Icons.inventory_2,
        title: 'Stok Cabang',
        onTap: () => context.go('/stocks'),
      ),
      _DashboardMenuEntry(
        path: '/stocks/receive',
        icon: Icons.add_box_outlined,
        title: 'Terima Stok',
        onTap: () => context.push('/stocks/receive', extra: user.branchId),
      ),
      _DashboardMenuEntry(
        path: '/stocks/locations/back',
        icon: Icons.warehouse_outlined,
        title: 'Gudang Cabang',
        onTap: () => context.go('/stocks/locations/back'),
      ),
      _DashboardMenuEntry(
        path: '/stocks/locations/front',
        icon: Icons.storefront_outlined,
        title: 'Stok Etalase',
        onTap: () => context.go('/stocks/locations/front'),
      ),
      _DashboardMenuEntry(
        path: '/stocks/replenish',
        icon: Icons.move_to_inbox_outlined,
        title: 'Isi Etalase',
        onTap: () => context.push('/stocks/replenish', extra: user.branchId),
      ),
      _DashboardMenuEntry(
        path: '/warehouse/opname',
        icon: Icons.fact_check_outlined,
        title: 'Stok Opname',
        onTap: () => context.push('/warehouse/opname'),
      ),
      _DashboardMenuEntry(
        path: '/warehouse/transfer',
        icon: Icons.swap_horiz,
        title: 'Transfer Stok',
        onTap: () => context.push('/warehouse/transfer'),
      ),
      _DashboardMenuEntry(
        path: '/stocks/central',
        icon: Icons.warehouse_outlined,
        title: 'Stok Gudang Pusat',
        onTap: () => context.go('/stocks/central'),
      ),
      _DashboardMenuEntry(
        path: '/distributions',
        icon: Icons.call_split,
        title: 'Distribusi',
        onTap: () => context.go('/distributions'),
      ),
    ];

List<_DashboardMenuEntry> _staffMenus(BuildContext context) => [
      _DashboardMenuEntry(
        path: '/orders',
        icon: Icons.add_shopping_cart,
        title: 'Buat Order',
        onTap: () => context.go('/orders'),
      ),
      _DashboardMenuEntry(
        path: '/stocks',
        icon: Icons.inventory_2,
        title: 'Cek Stok',
        onTap: () => context.go('/stocks'),
      ),
      _DashboardMenuEntry(
        path: '/reports/staff',
        icon: Icons.assignment_outlined,
        title: 'Laporan Order',
        onTap: () => context.go('/reports/staff'),
      ),
    ];

List<_DashboardMenuEntry> _cashierMenus(BuildContext context) => [
      _DashboardMenuEntry(
        path: '/cashier',
        icon: Icons.point_of_sale,
        title: 'Kasir',
        onTap: () => context.go('/cashier'),
      ),
      _DashboardMenuEntry(
        path: '/reports/cashier',
        icon: Icons.bar_chart_outlined,
        title: 'Laporan Kasir',
        onTap: () => context.go('/reports/cashier'),
      ),
      _DashboardMenuEntry(
        path: '/cashier/ledger',
        icon: Icons.account_balance_wallet_outlined,
        title: 'Kas Cabang',
        onTap: () => context.go('/cashier/ledger'),
      ),
      _DashboardMenuEntry(
        path: '/settings/printer',
        icon: Icons.print_outlined,
        title: 'Printer Thermal',
        onTap: () => context.push('/settings/printer'),
      ),
    ];
