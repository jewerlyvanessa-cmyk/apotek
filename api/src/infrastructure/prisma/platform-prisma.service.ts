import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';

/**
 * Koneksi DB untuk modul Platform (Super Admin).
 * Pakai PLATFORM_DATABASE_URL — role DB dengan hak tulis ke tabel tenants.
 */
@Injectable()
export class PlatformPrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  constructor(config: ConfigService) {
    const url =
      config.get<string>('PLATFORM_DATABASE_URL')?.trim() ||
      config.get<string>('DATABASE_URL');
    super({
      datasources: {
        db: { url },
      },
    });
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
