import { Module } from '@nestjs/common';
import { CashEntriesController } from './cash-entries.controller';
import { CashEntriesService } from './cash-entries.service';

@Module({
  controllers: [CashEntriesController],
  providers: [CashEntriesService],
  exports: [CashEntriesService],
})
export class CashEntriesModule {}
