export interface DatabaseConnectionParts {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
  schema?: string;
}

export function buildDatabaseUrl(parts: DatabaseConnectionParts): string {
  const user = encodeURIComponent(parts.user);
  const password = encodeURIComponent(parts.password);
  const schema = parts.schema ?? 'public';
  return `postgresql://${user}:${password}@${parts.host}:${parts.port}/${parts.database}?schema=${schema}`;
}

export function maskSecret(value?: string | null): string | null {
  if (!value?.trim()) return null;
  return '********';
}

export function maskDatabaseUrl(url: string): string {
  return url.replace(/:\/\/([^:]+):([^@]+)@/, '://$1:********@');
}
