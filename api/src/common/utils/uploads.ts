import { existsSync, mkdirSync } from 'fs';
import { join } from 'path';

export function ensureUploadsDir(subdir?: string) {
  const dir = subdir
    ? join(process.cwd(), 'uploads', subdir)
    : join(process.cwd(), 'uploads');
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
  return dir;
}

