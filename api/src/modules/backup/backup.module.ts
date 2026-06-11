import { Module } from '@nestjs/common';
import { PrismaModule } from '../../infrastructure/prisma/prisma.module';
import { PlatformModule } from '../platform/platform.module';
import { BackupController } from './backup.controller';

@Module({
  imports: [PrismaModule, PlatformModule],
  controllers: [BackupController],
})
export class BackupModule {}
