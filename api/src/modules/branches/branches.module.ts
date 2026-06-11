import { Module } from '@nestjs/common';
import { LicenseModule } from '../license/license.module';
import { BranchesController } from './branches.controller';
import { BranchesService } from './branches.service';

@Module({
  imports: [LicenseModule],
  controllers: [BranchesController],
  providers: [BranchesService],
})
export class BranchesModule {}
