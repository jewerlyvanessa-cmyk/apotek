import { Module } from '@nestjs/common';
import { LicenseModule } from '../license/license.module';
import { SetupController } from './setup.controller';
import { SetupService } from './setup.service';
import { SetupStorageService } from './setup-storage.service';

@Module({
  imports: [LicenseModule],
  controllers: [SetupController],
  providers: [SetupService, SetupStorageService],
  exports: [SetupService],
})
export class SetupModule {}
