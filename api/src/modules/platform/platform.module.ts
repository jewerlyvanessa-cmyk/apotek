import { Module } from '@nestjs/common';
import { PrismaModule } from '../../infrastructure/prisma/prisma.module';
import { PlatformPrismaService } from '../../infrastructure/prisma/platform-prisma.service';
import { LicenseModule } from '../license/license.module';
import { PlatformController } from './platform.controller';
import { PlatformBackupService } from './platform-backup.service';
import { PlatformService } from './platform.service';

@Module({
  imports: [PrismaModule, LicenseModule],
  controllers: [PlatformController],
  providers: [PlatformPrismaService, PlatformService, PlatformBackupService],
  exports: [PlatformBackupService],
})
export class PlatformModule {}
