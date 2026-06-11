import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Optional,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { ApiResponseDto } from './common/dto/api-response.dto';
import { PrismaService } from './infrastructure/prisma/prisma.service';
import { PlatformPrismaService } from './infrastructure/prisma/platform-prisma.service';
import { RedisCacheService } from './infrastructure/redis/redis.service';
import { LicenseService } from './modules/license/license.service';
import { SetupService } from './modules/setup/setup.service';

type CheckResult = { ok: boolean; latency_ms?: number; message?: string };

@Controller('health')
export class HealthController {
  constructor(
    private license: LicenseService,
    private setup: SetupService,
    private prisma: PrismaService,
    @Optional() private platformPrisma: PlatformPrismaService | null,
    private cache: RedisCacheService,
  ) {}

  private async checkDatabase(
    client: PrismaService | PlatformPrismaService,
    label: string,
  ): Promise<CheckResult> {
    const start = Date.now();
    try {
      await client.$queryRaw`SELECT 1`;
      return { ok: true, latency_ms: Date.now() - start };
    } catch (e) {
      return {
        ok: false,
        latency_ms: Date.now() - start,
        message: `${label}: ${e instanceof Error ? e.message : 'unavailable'}`,
      };
    }
  }

  @Get()
  async health(@Res({ passthrough: true }) res: Response) {
    const install = this.license.isOnPrem()
      ? this.license.getInstallationStatus()
      : undefined;
    const setup = await this.setup.getStatus();

    const [database, platformDatabase, redis] = await Promise.all([
      this.checkDatabase(this.prisma, 'database'),
      this.platformPrisma
        ? this.checkDatabase(this.platformPrisma, 'platform_database')
        : Promise.resolve<CheckResult>({
            ok: true,
            message: 'platform module disabled',
          }),
      this.cache.healthCheck(),
    ]);

    const checks = {
      database,
      platform_database: platformDatabase,
      redis: {
        enabled: redis.enabled,
        ok: redis.ok,
      },
    };

    const coreOk = database.ok && platformDatabase.ok;
    const status = coreOk ? 'ok' : 'degraded';

    if (!coreOk) {
      res.status(HttpStatus.SERVICE_UNAVAILABLE);
    }

    return ApiResponseDto.ok({
      status,
      service: 'apotikflow-api',
      deployment_mode: this.license.getDeploymentMode(),
      license_valid: install?.valid ?? true,
      setup_required: setup.setup_required,
      database_configured: setup.database_configured,
      schema_ready: setup.schema_ready,
      perpetual_database_setup_enabled: setup.perpetual_database_setup_enabled,
      checks,
      sentry_configured: !!process.env.SENTRY_DSN?.trim(),
    });
  }

  @Get('live')
  @HttpCode(HttpStatus.OK)
  live() {
    return ApiResponseDto.ok({ status: 'ok', probe: 'liveness' });
  }
}
