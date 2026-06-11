/**
 * Generate license key untuk deployment on-prem.
 *
 * Beli putus:
 *   npm run license:generate -- --customer "PT Apotek" --type perpetual --plan single --tenant DEMO
 *
 * Berlangganan:
 *   npm run license:generate -- --customer "PT Apotek" --type subscription --plan starter --tenant DEMO
 */
import { config } from 'dotenv';
import { resolveLicensePlan } from '../src/modules/license/license-plans';
import { signLicensePayload } from '../src/modules/license/license-token.util';
import { LicensePayload } from '../src/modules/license/license.types';

config();

function arg(name: string): string | undefined {
  const idx = process.argv.indexOf(`--${name}`);
  if (idx === -1 || idx + 1 >= process.argv.length) return undefined;
  return process.argv[idx + 1];
}

const customer = arg('customer') ?? 'Customer';
const type = (arg('type') ?? 'perpetual') as 'perpetual' | 'subscription';
const planId = arg('plan');
const tenantCode = arg('tenant');
let maxBranches = arg('max-branches');
let days = arg('days');

const planDef = resolveLicensePlan(planId, type);
if (planDef && planDef.id !== 'custom') {
  if (planDef.max_branches) maxBranches = String(planDef.max_branches);
  if (type === 'subscription' && planDef.days) {
    days = String(planDef.days);
  }
}

const secret =
  process.env.LICENSE_SECRET?.trim() ||
  process.env.JWT_SECRET?.trim() ||
  'change-me-in-production';

const payload: LicensePayload = {
  v: 1,
  type,
  customer,
  iat: Math.floor(Date.now() / 1000),
  ...(planDef && planDef.id !== 'custom' ? { plan: planDef.id } : {}),
  ...(tenantCode ? { tenant_code: tenantCode.toUpperCase() } : {}),
  ...(maxBranches ? { max_branches: parseInt(maxBranches, 10) } : {}),
  ...(type === 'subscription' && days
    ? { exp: Math.floor(Date.now() / 1000) + parseInt(days, 10) * 86400 }
    : {}),
};

const key = signLicensePayload(payload, secret);

console.log('\nApotikFlow License Key\n');
console.log(key);
console.log('\nPayload:', JSON.stringify(payload, null, 2));
console.log(
  '\nSet di server: LICENSE_KEY="<key>" atau POST /api/v1/license/activate',
);
