import '../../features/auth/domain/entities/auth_user.dart';

/// Apakah [path] boleh diakses user saat ini.
/// Staff/Kasir: semua peran ditugaskan di cabang aktif (tanpa wajib ganti peran).
bool isRouteAllowedForActiveRole(String path, AuthUser user) {
  final role = user.role;
  bool activeIs(String r) => role == r;
  bool assignedIs(String r) => user.hasRoleInBranch(r);

  const sharedPaths = {
    '/home',
    '/pending-actions',
    '/notifications',
    '/search',
    '/scan',
    '/stock-movements',
    '/activate-license',
  };
  if (sharedPaths.contains(path)) return true;
  if (path.startsWith('/stocks/receive')) return role != 'SUPER_ADMIN';
  if (path == '/stocks/replenish' || path.startsWith('/stocks/locations/')) {
    return activeIs('OWNER') ||
        activeIs('MANAGER') ||
        activeIs('WAREHOUSE');
  }
  if (path.startsWith('/admin/users')) {
    return activeIs('OWNER') || user.isTenantWideManager;
  }
  if (path.startsWith('/admin/branches/') && path.endsWith('/stock-mode')) {
    return activeIs('OWNER') || activeIs('MANAGER');
  }
  if (path.startsWith('/payments/') || path.startsWith('/orders/')) {
    return role != 'SUPER_ADMIN';
  }
  if (path == '/medicines/new' ||
      path == '/medicines/master' ||
      (path.startsWith('/medicines/') && path.endsWith('/edit'))) {
    return user.canManageCatalog;
  }

  if (path.startsWith('/platform')) return activeIs('SUPER_ADMIN');

  if (path.startsWith('/cashier') || path == '/reports/cashier') {
    return assignedIs('CASHIER');
  }
  if (path == '/ledger') {
    return activeIs('OWNER') || activeIs('MANAGER');
  }
  if (path == '/orders') return assignedIs('STAFF');
  if (path == '/reports/staff') {
    return assignedIs('STAFF') || assignedIs('PHARMACIST');
  }
  if (path == '/reports/branch') {
    return activeIs('MANAGER') && user.isBranchManager;
  }
  if (path == '/pharmacy/reviews') {
    return activeIs('PHARMACIST') || activeIs('OWNER');
  }
  if (path == '/customers') {
    return activeIs('OWNER') || activeIs('MANAGER');
  }
  if (path.startsWith('/admin')) {
    return activeIs('OWNER') || activeIs('MANAGER');
  }
  if (path == '/reports') {
    return activeIs('OWNER') ||
        (activeIs('MANAGER') && user.isTenantWideManager);
  }
  if (path == '/backup') {
    return activeIs('OWNER') || activeIs('MANAGER');
  }
  if (path.startsWith('/warehouse/')) {
    return activeIs('OWNER') || activeIs('MANAGER') || activeIs('WAREHOUSE');
  }
  if (path == '/medicines') {
    return activeIs('OWNER') ||
        activeIs('MANAGER') ||
        activeIs('PHARMACIST') ||
        activeIs('WAREHOUSE');
  }
  if (path == '/warehouse') {
    return activeIs('OWNER') ||
        activeIs('MANAGER') ||
        activeIs('WAREHOUSE');
  }
  if (path.startsWith('/procurements')) {
    return activeIs('OWNER') ||
        (activeIs('MANAGER') && user.isTenantWideManager);
  }
  if (path == '/stocks/central') {
    return activeIs('OWNER') ||
        (activeIs('MANAGER') && user.isTenantWideManager) ||
        activeIs('WAREHOUSE');
  }
  if (path == '/distributions') {
    return activeIs('OWNER') ||
        activeIs('MANAGER') ||
        activeIs('WAREHOUSE');
  }
  if (path == '/stocks') return role != 'SUPER_ADMIN';
  if (path == '/alerts/expired') {
    return activeIs('OWNER') ||
        activeIs('MANAGER') ||
        activeIs('PHARMACIST') ||
        activeIs('WAREHOUSE');
  }
  if (path == '/license-status') return activeIs('OWNER');
  if (path == '/settings/printer') {
    return activeIs('OWNER') ||
        activeIs('MANAGER') ||
        assignedIs('CASHIER');
  }

  return true;
}
