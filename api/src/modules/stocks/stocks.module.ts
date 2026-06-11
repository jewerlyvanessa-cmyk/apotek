import { Module } from '@nestjs/common';
import { RealtimeModule } from '../realtime/realtime.module';
import { StocksController } from './stocks.controller';
import { StocksService } from './stocks.service';

@Module({
  imports: [RealtimeModule],
  controllers: [StocksController],
  providers: [StocksService],
  exports: [StocksService],
})
export class StocksModule {}
