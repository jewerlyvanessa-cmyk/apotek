import { Module } from '@nestjs/common';
import { APP_FILTER } from '@nestjs/core';
import { SentryGlobalFilter, SentryModule } from '@sentry/nestjs/setup';
import { ConfigModule } from '@nestjs/config';
import { join } from 'path';
import { PrismaModule } from './infrastructure/prisma/prisma.module';
import { MailModule } from './infrastructure/mail/mail.module';
import { AuthModule } from './modules/auth/auth.module';
import { BranchesModule } from './modules/branches/branches.module';
import { UsersModule } from './modules/users/users.module';
import { CategoriesModule } from './modules/categories/categories.module';
import { UnitsModule } from './modules/units/units.module';
import { ProductTypesModule } from './modules/product-types/product-types.module';
import { SuppliersModule } from './modules/suppliers/suppliers.module';
import { CustomersModule } from './modules/customers/customers.module';
import { MedicinesModule } from './modules/medicines/medicines.module';
import { StocksModule } from './modules/stocks/stocks.module';
import { OrdersModule } from './modules/orders/orders.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { StockOpnamesModule } from './modules/stock-opnames/stock-opnames.module';
import { TransferStocksModule } from './modules/transfer-stocks/transfer-stocks.module';
import { StockInternalMovesModule } from './modules/stock-internal-moves/stock-internal-moves.module';
import { ProcurementsModule } from './modules/procurements/procurements.module';
import { ReportsModule } from './modules/reports/reports.module';
import { CashEntriesModule } from './modules/cash-entries/cash-entries.module';
import { RealtimeModule } from './modules/realtime/realtime.module';
import { WebsocketModule } from './websocket/websocket.module';
import { HealthController } from './health.controller';
import { AuditLogsModule } from './modules/audit-logs/audit-logs.module';
import { ScheduleModule } from '@nestjs/schedule';
import { ExpiredAlertsModule } from './modules/expired-alerts/expired-alerts.module';
import { RedisModule } from './infrastructure/redis/redis.module';
import { JobsModule } from './modules/jobs/jobs.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { BackupModule } from './modules/backup/backup.module';
import { LicenseModule } from './modules/license/license.module';
import { PlatformModule } from './modules/platform/platform.module';
import { BillingModule } from './modules/billing/billing.module';
import { SetupModule } from './modules/setup/setup.module';

/** BullMQ membutuhkan Redis — tanpa REDIS_URL modul jobs tidak dimuat. */
const optionalJobsModule = process.env.REDIS_URL?.trim() ? [JobsModule] : [];

const deploymentMode = (process.env.DEPLOYMENT_MODE ?? 'saas')
  .trim()
  .toLowerCase();
const isOnPrem =
  deploymentMode === 'on_prem' ||
  deploymentMode === 'onprem' ||
  deploymentMode === 'on-prem';
const enablePlatform =
  process.env.ENABLE_PLATFORM === 'true' ||
  (!isOnPrem && process.env.ENABLE_PLATFORM !== 'false');
const optionalPlatformModule = enablePlatform ? [PlatformModule] : [];

const sentryEnabled = !!process.env.SENTRY_DSN?.trim();
const sentryImports = sentryEnabled ? [SentryModule.forRoot()] : [];
const sentryProviders = sentryEnabled
  ? [{ provide: APP_FILTER, useClass: SentryGlobalFilter }]
  : [];

@Module({
  imports: [
    ...sentryImports,
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: [
        join(process.cwd(), 'data', 'config.env'),
        join(process.cwd(), '.env'),
      ],
    }),
    PrismaModule,
    MailModule,
    RedisModule,
    AuditLogsModule,
    ScheduleModule.forRoot(),
    WebsocketModule,
    RealtimeModule,
    AuthModule,
    BranchesModule,
    UsersModule,
    CategoriesModule,
    UnitsModule,
    ProductTypesModule,
    SuppliersModule,
    CustomersModule,
    MedicinesModule,
    StocksModule,
    OrdersModule,
    PaymentsModule,
    StockOpnamesModule,
    TransferStocksModule,
    StockInternalMovesModule,
    ProcurementsModule,
    ReportsModule,
    CashEntriesModule,
    ExpiredAlertsModule,
    ...optionalJobsModule,
    NotificationsModule,
    BackupModule,
    LicenseModule,
    BillingModule,
    SetupModule,
    ...optionalPlatformModule,
  ],
  controllers: [HealthController],
  providers: [...sentryProviders],
})
export class AppModule {}
