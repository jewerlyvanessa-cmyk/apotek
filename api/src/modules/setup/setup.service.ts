import {
  BadRequestException,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Client } from 'pg';
import { execFile } from 'child_process';
import { promisify } from 'util';
import { readFileSync } from 'fs';
import { join } from 'path';
import { LicenseService } from '../license/license.service';
import {
  buildDatabaseUrl,
  maskDatabaseUrl,
  maskSecret,
} from './database-url.util';
import {
  DatabaseConnectionDto,
  DatabaseSetupDto,
} from './dto/database-connection.dto';
import {
  SetupStorageService,
  StoredDatabaseSettings,
} from './setup-storage.service';

const execFileAsync = promisify(execFile);

@Injectable()
export class SetupService {
  constructor(
    private config: ConfigService,
    private license: LicenseService,
    private storage: SetupStorageService,
  ) {}

  private defaultAppUser(): string {
    return 'apotikflow_app';
  }

  private defaultPlatformUser(): string {
    return 'apotikflow_platform';
  }

  canManageDatabase(): boolean {
    if (!this.license.isOnPrem()) return false;
    const payload = this.license.getInstallationPayload();
    if (!payload) return true;
    return payload.type === 'perpetual';
  }

  assertDatabaseManagement(role?: string): void {
    if (!this.canManageDatabase()) {
      throw new ForbiddenException(
        'Pengaturan database hanya untuk instalasi beli putus (perpetual) on-prem',
      );
    }
    if (role !== 'SUPER_ADMIN') {
      throw new ForbiddenException(
        'Pengaturan database hanya untuk Super Admin',
      );
    }
  }

  private resolveSettings(dto: DatabaseSetupDto): StoredDatabaseSettings {
    const stored = this.storage.readSettings();
    return {
      host: dto.host.trim(),
      port: dto.port,
      database: dto.database.trim(),
      app_user: dto.app_user?.trim() || stored?.app_user || this.defaultAppUser(),
      app_password:
        dto.app_password?.trim() ||
        stored?.app_password ||
        'apotikflow_app_secret',
      platform_user:
        dto.platform_user?.trim() ||
        stored?.platform_user ||
        this.defaultPlatformUser(),
      platform_password:
        dto.platform_password?.trim() ||
        stored?.platform_password ||
        'apotikflow_platform_secret',
      migrate_user:
        dto.migrate_user?.trim() ||
        dto.admin_user?.trim() ||
        stored?.migrate_user ||
        dto.user.trim(),
      migrate_password:
        dto.migrate_password?.trim() ||
        dto.admin_password?.trim() ||
        stored?.migrate_password ||
        dto.password,
      updated_at: new Date().toISOString(),
    };
  }

  async testConnection(dto: DatabaseConnectionDto, role?: string) {
    this.assertDatabaseManagement(role);
    const url = buildDatabaseUrl({
      host: dto.host.trim(),
      port: dto.port,
      database: dto.database.trim(),
      user: dto.user.trim(),
      password: dto.password,
    });

    const client = new Client({ connectionString: url });
    try {
      await client.connect();
      await client.query('SELECT 1');
      return { ok: true, message: 'Koneksi database berhasil' };
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Koneksi gagal';
      return { ok: false, message };
    } finally {
      await client.end().catch(() => undefined);
    }
  }

  async createDatabase(dto: DatabaseSetupDto, role?: string) {
    this.assertDatabaseManagement(role);
    const adminUser = dto.admin_user?.trim() || dto.user.trim();
    const adminPassword = dto.admin_password?.trim() || dto.password;
    const dbName = dto.database.trim();
    const settings = this.resolveSettings(dto);

    const adminClient = new Client({
      host: dto.host.trim(),
      port: dto.port,
      user: adminUser,
      password: adminPassword,
      database: 'postgres',
    });

    try {
      await adminClient.connect();
      const exists = await adminClient.query(
        'SELECT 1 FROM pg_database WHERE datname = $1',
        [dbName],
      );
      if ((exists.rowCount ?? 0) === 0) {
        await adminClient.query(`CREATE DATABASE "${dbName.replace(/"/g, '')}"`);
      }
    } finally {
      await adminClient.end().catch(() => undefined);
    }

    const dbClient = new Client({
      host: dto.host.trim(),
      port: dto.port,
      user: adminUser,
      password: adminPassword,
      database: dbName,
    });

    try {
      await dbClient.connect();
      await this.ensureRoles(dbClient, settings);
    } finally {
      await dbClient.end().catch(() => undefined);
    }

    this.storage.writeSettings(settings);

    return {
      ok: true,
      message: `Database "${dbName}" siap. Jalankan migrasi schema lalu terapkan konfigurasi.`,
      database: dbName,
    };
  }

  private async ensureRoles(
    client: Client,
    settings: StoredDatabaseSettings,
  ): Promise<void> {
    const roles: Array<{ name: string; password: string }> = [
      { name: settings.app_user, password: settings.app_password },
      { name: settings.platform_user, password: settings.platform_password },
    ];

    for (const role of roles) {
      const safeName = role.name.replace(/"/g, '');
      const safePassword = role.password.replace(/'/g, "''");
      const exists = await client.query(
        'SELECT 1 FROM pg_roles WHERE rolname = $1',
        [safeName],
      );
      if ((exists.rowCount ?? 0) === 0) {
        await client.query(
          `CREATE ROLE "${safeName}" WITH LOGIN PASSWORD '${safePassword}'`,
        );
      } else {
        await client.query(
          `ALTER ROLE "${safeName}" WITH LOGIN PASSWORD '${safePassword}'`,
        );
      }
      await client.query(`GRANT CONNECT ON DATABASE CURRENT_CATALOG TO "${safeName}"`);
      await client.query(`GRANT USAGE ON SCHEMA public TO "${safeName}"`);
    }
  }

  async applyDatabaseConfig(dto: DatabaseSetupDto, role?: string) {
    this.assertDatabaseManagement(role);
    const settings = this.resolveSettings(dto);

    const appUrl = buildDatabaseUrl({
      host: settings.host,
      port: settings.port,
      database: settings.database,
      user: settings.app_user,
      password: settings.app_password,
    });
    const platformUrl = buildDatabaseUrl({
      host: settings.host,
      port: settings.port,
      database: settings.database,
      user: settings.platform_user,
      password: settings.platform_password,
    });
    const migrateUrl = buildDatabaseUrl({
      host: settings.host,
      port: settings.port,
      database: settings.database,
      user: settings.migrate_user,
      password: settings.migrate_password,
    });

    const test = await this.testConnection({
      host: settings.host,
      port: settings.port,
      database: settings.database,
      user: settings.migrate_user,
      password: settings.migrate_password,
    });
    if (!test.ok) {
      throw new BadRequestException(
        `Koneksi migrate gagal: ${test.message}`,
      );
    }

    this.storage.writeSettings(settings);
    this.storage.writeRuntimeConfigEnv({
      DATABASE_URL: appUrl,
      PLATFORM_DATABASE_URL: platformUrl,
      DATABASE_URL_MIGRATE: migrateUrl,
      DEPLOYMENT_MODE: 'on_prem',
    });

    return {
      ok: true,
      restart_required: true,
      message:
        'Konfigurasi database disimpan. Restart service API agar koneksi baru aktif.',
      database_url_masked: maskDatabaseUrl(appUrl),
      platform_database_url_masked: maskDatabaseUrl(platformUrl),
    };
  }

  async runMigrations(dto?: DatabaseSetupDto, role?: string) {
    this.assertDatabaseManagement(role);
    const settings = dto ? this.resolveSettings(dto) : this.storage.readSettings();
    if (!settings) {
      throw new BadRequestException(
        'Belum ada pengaturan database. Isi form atau buat database terlebih dahulu.',
      );
    }

    const migrateUrl = buildDatabaseUrl({
      host: settings.host,
      port: settings.port,
      database: settings.database,
      user: settings.migrate_user,
      password: settings.migrate_password,
    });

    try {
      const { stdout, stderr } = await execFileAsync(
        process.platform === 'win32' ? 'npx.cmd' : 'npx',
        ['prisma', 'migrate', 'deploy'],
        {
          cwd: process.cwd(),
          env: {
            ...process.env,
            DATABASE_URL: migrateUrl,
          },
          maxBuffer: 10 * 1024 * 1024,
        },
      );

      await this.applyTenantPermissions(settings, migrateUrl);

      if (dto) this.storage.writeSettings(settings);

      return {
        ok: true,
        message: 'Migrasi schema selesai',
        output: `${stdout}\n${stderr}`.trim(),
      };
    } catch (err) {
      const output =
        err && typeof err === 'object' && 'stdout' in err
          ? `${(err as { stdout?: string }).stdout ?? ''}\n${(err as { stderr?: string }).stderr ?? ''}`
          : err instanceof Error
            ? err.message
            : 'Migrasi gagal';
      throw new BadRequestException({
        message: 'Migrasi schema gagal',
        output: output.trim(),
      });
    }
  }

  private async applyTenantPermissions(
    settings: StoredDatabaseSettings,
    migrateUrl: string,
  ): Promise<void> {
    const sqlPath = join(process.cwd(), 'prisma', 'sql', 'tenant-db-permissions.sql');
    let sql = readFileSync(sqlPath, 'utf8');
    sql = sql
      .replace(/apotikflow_app_secret/g, settings.app_password)
      .replace(/apotikflow_platform_secret/g, settings.platform_password);

    const client = new Client({ connectionString: migrateUrl });
    try {
      await client.connect();
      await client.query(sql);
    } finally {
      await client.end().catch(() => undefined);
    }
  }

  async getDatabaseConfig(role?: string) {
    this.assertDatabaseManagement(role);
    const stored = this.storage.readSettings();
    const databaseUrl = this.config.get<string>('DATABASE_URL');
    const platformUrl = this.config.get<string>('PLATFORM_DATABASE_URL');

    return {
      configured: !!stored || !!databaseUrl,
      has_runtime_config: this.storage.hasRuntimeConfig(),
      settings: stored
        ? {
            host: stored.host,
            port: stored.port,
            database: stored.database,
            app_user: stored.app_user,
            app_password: maskSecret(stored.app_password),
            platform_user: stored.platform_user,
            platform_password: maskSecret(stored.platform_password),
            migrate_user: stored.migrate_user,
            migrate_password: maskSecret(stored.migrate_password),
            updated_at: stored.updated_at,
          }
        : null,
      active: {
        database_url_masked: databaseUrl
          ? maskDatabaseUrl(databaseUrl)
          : null,
        platform_database_url_masked: platformUrl
          ? maskDatabaseUrl(platformUrl)
          : null,
      },
    };
  }

  async getStatus() {
    const canManage = this.canManageDatabase();
    const stored = this.storage.readSettings();
    let dbConnected = false;
    let schemaReady = false;
    let dbMessage: string | null = null;

    const databaseUrl =
      this.config.get<string>('DATABASE_URL') ||
      (stored
        ? buildDatabaseUrl({
            host: stored.host,
            port: stored.port,
            database: stored.database,
            user: stored.app_user,
            password: stored.app_password,
          })
        : null);

    if (databaseUrl) {
      const client = new Client({ connectionString: databaseUrl });
      try {
        await client.connect();
        dbConnected = true;
        const migrations = await client.query(
          `SELECT to_regclass('public._prisma_migrations') AS tbl`,
        );
        const tenants = await client.query(
          `SELECT to_regclass('public.tenants') AS tbl`,
        );
        schemaReady =
          migrations.rows[0]?.tbl != null || tenants.rows[0]?.tbl != null;
      } catch (err) {
        dbMessage = err instanceof Error ? err.message : 'Database tidak terhubung';
      } finally {
        await client.end().catch(() => undefined);
      }
    }

    const install = this.license.isOnPrem()
      ? this.license.getInstallationStatus()
      : undefined;

    const setupRequired =
      this.license.isOnPrem() &&
      canManage &&
      (!dbConnected || !schemaReady);

    return {
      deployment_mode: this.license.getDeploymentMode(),
      perpetual_database_setup_enabled: canManage,
      database_configured: dbConnected,
      schema_ready: schemaReady,
      setup_required: setupRequired,
      database_message: dbMessage,
      license_valid: install?.valid ?? !this.license.isOnPrem(),
      license_type: install?.type ?? null,
      config_file_exists: this.storage.hasRuntimeConfig(),
    };
  }
}
