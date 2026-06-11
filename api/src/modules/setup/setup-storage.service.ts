import { Injectable } from '@nestjs/common';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { join } from 'path';

export interface StoredDatabaseSettings {
  host: string;
  port: number;
  database: string;
  app_user: string;
  app_password: string;
  platform_user: string;
  platform_password: string;
  migrate_user: string;
  migrate_password: string;
  updated_at: string;
}

@Injectable()
export class SetupStorageService {
  private dataDir(): string {
    return join(process.cwd(), 'data');
  }

  settingsPath(): string {
    return join(this.dataDir(), 'database.settings.json');
  }

  configEnvPath(): string {
    return join(this.dataDir(), 'config.env');
  }

  ensureDataDir(): void {
    const dir = this.dataDir();
    if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  }

  readSettings(): StoredDatabaseSettings | null {
    const path = this.settingsPath();
    if (!existsSync(path)) return null;
    try {
      return JSON.parse(readFileSync(path, 'utf8')) as StoredDatabaseSettings;
    } catch {
      return null;
    }
  }

  writeSettings(settings: StoredDatabaseSettings): void {
    this.ensureDataDir();
    writeFileSync(this.settingsPath(), JSON.stringify(settings, null, 2), 'utf8');
  }

  writeRuntimeConfigEnv(lines: Record<string, string>): void {
    this.ensureDataDir();
    const content = Object.entries(lines)
      .map(([key, value]) => `${key}="${value.replace(/"/g, '\\"')}"`)
      .join('\n')
      .concat('\n');
    writeFileSync(this.configEnvPath(), content, 'utf8');
  }

  hasRuntimeConfig(): boolean {
    return existsSync(this.configEnvPath());
  }
}
