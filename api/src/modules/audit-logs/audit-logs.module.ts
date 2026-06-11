import { Global, Module } from '@nestjs/common';
import { PrismaModule } from '../../infrastructure/prisma/prisma.module';
import { AuditLogsService } from './audit-logs.service';

@Global()
@Module({
  imports: [PrismaModule],
  providers: [AuditLogsService],
  exports: [AuditLogsService],
})
export class AuditLogsModule {}

