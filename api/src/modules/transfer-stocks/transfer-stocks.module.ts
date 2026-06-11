import { Module } from '@nestjs/common';
import { RealtimeModule } from '../realtime/realtime.module';
import { TransferStocksController } from './transfer-stocks.controller';
import { TransferStocksService } from './transfer-stocks.service';

@Module({
  imports: [RealtimeModule],
  controllers: [TransferStocksController],
  providers: [TransferStocksService],
})
export class TransferStocksModule {}

