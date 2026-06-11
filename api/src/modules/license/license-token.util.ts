import { createHmac, timingSafeEqual } from 'crypto';
import { LicensePayload } from './license.types';

const PREFIX = 'aflow_';

function b64urlEncode(data: string): string {
  return Buffer.from(data, 'utf8')
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function b64urlDecode(data: string): string {
  const pad = data.length % 4 === 0 ? '' : '='.repeat(4 - (data.length % 4));
  const normalized = data.replace(/-/g, '+').replace(/_/g, '/') + pad;
  return Buffer.from(normalized, 'base64').toString('utf8');
}

export function signLicensePayload(
  payload: LicensePayload,
  secret: string,
): string {
  const body = b64urlEncode(JSON.stringify(payload));
  const sig = createHmac('sha256', secret).update(body).digest('base64url');
  return `${PREFIX}${body}.${sig}`;
}

export function verifyLicenseToken(
  token: string,
  secret: string,
  options?: { allowExpired?: boolean },
): LicensePayload | null {
  const trimmed = token.trim();
  if (!trimmed.startsWith(PREFIX)) return null;
  const raw = trimmed.slice(PREFIX.length);
  const dot = raw.lastIndexOf('.');
  if (dot <= 0) return null;

  const body = raw.slice(0, dot);
  const sig = raw.slice(dot + 1);
  const expected = createHmac('sha256', secret).update(body).digest('base64url');

  try {
    const a = Buffer.from(sig);
    const b = Buffer.from(expected);
    if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
  } catch {
    return null;
  }

  try {
    const parsed = JSON.parse(b64urlDecode(body)) as LicensePayload;
    if (!parsed || parsed.v !== 1 || !parsed.customer) return null;
    if (
      parsed.exp &&
      parsed.exp * 1000 < Date.now() &&
      !options?.allowExpired
    ) {
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}
