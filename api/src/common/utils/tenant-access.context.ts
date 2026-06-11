import { AsyncLocalStorage } from 'async_hooks';
import { ForbiddenException } from '@nestjs/common';

/** Field tenant yang boleh dibaca tanpa konteks Super Admin (mis. label UI login). */
export const TENANT_PUBLIC_SELECT = {
  id: true,
  name: true,
  code: true,
} as const;

const tenantAccessStore = new AsyncLocalStorage<boolean>();

export function isFullTenantAccessAllowed(): boolean {
  return tenantAccessStore.getStore() === true;
}

export function runWithFullTenantAccess<T>(fn: () => T): T {
  return tenantAccessStore.run(true, fn);
}

const PUBLIC_READ_FIELDS = new Set(['id', 'name', 'code', 'isActive']);

/** Baca status langganan untuk cek lisensi (on-prem / SaaS). */
const LICENSE_READ_FIELDS = new Set([
  'id',
  'name',
  'code',
  'isActive',
  'subscriptionPlan',
  'subscriptionExpiredAt',
]);

/** Sinkron paket langganan dari aktivasi lisensi on-prem. */
const LICENSE_WRITE_FIELDS = new Set([
  'subscriptionPlan',
  'subscriptionExpiredAt',
  'isActive',
]);

function selectedFields(args: Record<string, unknown>): string[] {
  const select = args?.select as Record<string, boolean> | undefined;
  if (!select || typeof select !== 'object') return [];
  return Object.keys(select).filter((k) => select[k] === true);
}

function isPublicTenantRead(operation: string, args: Record<string, unknown>): boolean {
  if (!['findUnique', 'findFirst', 'findMany'].includes(operation)) {
    return false;
  }
  const keys = selectedFields(args);
  return keys.length > 0 && keys.every((k) => PUBLIC_READ_FIELDS.has(k));
}

function isLicenseTenantRead(operation: string, args: Record<string, unknown>): boolean {
  if (!['findUnique', 'findFirst', 'findMany'].includes(operation)) {
    return false;
  }
  const keys = selectedFields(args);
  return keys.length > 0 && keys.every((k) => LICENSE_READ_FIELDS.has(k));
}

function isLicenseTenantWrite(operation: string, args: Record<string, unknown>): boolean {
  if (!['update', 'updateMany'].includes(operation)) return false;
  const data = args?.data as Record<string, unknown> | undefined;
  if (!data || typeof data !== 'object') return false;
  const keys = Object.keys(data);
  return keys.length > 0 && keys.every((k) => LICENSE_WRITE_FIELDS.has(k));
}

export function assertTenantModelAccess(
  operation: string,
  args: Record<string, unknown>,
): void {
  if (isFullTenantAccessAllowed()) return;
  if (isPublicTenantRead(operation, args)) return;
  if (isLicenseTenantRead(operation, args)) return;
  if (isLicenseTenantWrite(operation, args)) return;
  throw new ForbiddenException(
    'Akses tabel tenant hanya untuk Super Admin',
  );
}
