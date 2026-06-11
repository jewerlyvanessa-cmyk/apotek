import { LicenseType } from './license.types';

export interface LicensePlan {
  id: string;
  label: string;
  description: string;
  license_type: LicenseType;
  max_branches: number | null;
  /** null = tanpa kedaluwarsa (beli putus) */
  days: number | null;
}

/** Beli putus — server pembeli, tanpa masa berlaku. */
export const PERPETUAL_PLANS: LicensePlan[] = [
  {
    id: 'single',
    label: 'Single',
    description: '1 cabang · lisensi selamanya',
    license_type: 'perpetual',
    max_branches: 1,
    days: null,
  },
  {
    id: 'standard',
    label: 'Standard',
    description: '3 cabang · lisensi selamanya',
    license_type: 'perpetual',
    max_branches: 3,
    days: null,
  },
  {
    id: 'enterprise',
    label: 'Enterprise',
    description: '10 cabang · lisensi selamanya',
    license_type: 'perpetual',
    max_branches: 10,
    days: null,
  },
  {
    id: 'custom',
    label: 'Kustom',
    description: 'Atur maks. cabang sendiri · selamanya',
    license_type: 'perpetual',
    max_branches: null,
    days: null,
  },
];

/** Berlangganan on-prem — perpanjangan tahunan via kode lisensi. */
export const SUBSCRIPTION_PLANS: LicensePlan[] = [
  {
    id: 'starter',
    label: 'Starter',
    description: '1 cabang · berlaku 1 tahun',
    license_type: 'subscription',
    max_branches: 1,
    days: 365,
  },
  {
    id: 'professional',
    label: 'Profesional',
    description: '3 cabang · berlaku 1 tahun',
    license_type: 'subscription',
    max_branches: 3,
    days: 365,
  },
  {
    id: 'enterprise',
    label: 'Enterprise',
    description: '10 cabang · berlaku 1 tahun',
    license_type: 'subscription',
    max_branches: 10,
    days: 365,
  },
  {
    id: 'custom',
    label: 'Kustom',
    description: 'Atur maks. cabang dan masa berlaku sendiri',
    license_type: 'subscription',
    max_branches: null,
    days: null,
  },
];

export interface LicensePlanCatalog {
  perpetual_plans: LicensePlan[];
  subscription_plans: LicensePlan[];
}

export const LICENSE_PLAN_CATALOG: LicensePlanCatalog = {
  perpetual_plans: PERPETUAL_PLANS,
  subscription_plans: SUBSCRIPTION_PLANS,
};

export function resolveLicensePlan(
  planId?: string,
  type: LicenseType = 'perpetual',
): LicensePlan | null {
  if (!planId?.trim()) return null;
  const list =
    type === 'subscription' ? SUBSCRIPTION_PLANS : PERPETUAL_PLANS;
  return list.find((p) => p.id === planId.trim()) ?? null;
}

/** Nilai `subscription_plan` di tabel tenant — id paket katalog, bukan tipe lisensi. */
export function resolveTenantSubscriptionPlan(input: {
  type: LicenseType;
  plan?: string;
}): string {
  const trimmed = input.plan?.trim();
  if (trimmed) {
    const known = resolveLicensePlan(trimmed, input.type);
    if (known) return known.id;
    return trimmed;
  }
  return 'custom';
}
