import { Module } from '@nestjs/common';
import { RealtimeModule } from '../realtime/realtime.module';
import { StockInternalMovesController } from './stock-internal-moves.controller';
import { StockInternalMovesService } from './stock-internal-moves.service';

@Module({
  imports: [RealtimeModule],
  controllers: [StockInternalMovesController],
  providers: [StockInternalMovesService],
  exports: [StockInternalMovesService],
})
export class StockInternalMovesModule {}
