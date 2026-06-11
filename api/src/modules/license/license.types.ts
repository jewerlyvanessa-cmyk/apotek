export type DeploymentMode = 'saas' | 'on_prem';

export type LicenseType = 'perpetual' | 'subscription';

export interface LicensePayload {
  v: number;
  type: LicenseType;
  customer: string;
  plan?: string;
  tenant_code?: string;
  max_branches?: number;
  iat: number;
  exp?: number;
}

export interface InstallationLicenseStatus {
  valid: boolean;
  type?: LicenseType;
  customer?: string;
  plan?: string;
  tenant_code?: string;
  max_branches?: number;
  expires_at?: string | null;
  tenants_updated?: string[];
  message?: string;
}

export interface TenantSubscriptionStatus {
  valid: boolean;
  plan?: string | null;
  expires_at?: string | null;
  days_remaining?: number | null;
  in_grace_period?: boolean;
  message?: string;
}

export interface LicenseStatusResponse {
  deployment_mode: DeploymentMode;
  installation?: InstallationLicenseStatus;
  tenant?: TenantSubscriptionStatus;
}
