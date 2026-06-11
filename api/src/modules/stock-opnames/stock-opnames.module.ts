import { Module } from '@nestjs/common';
import { RealtimeModule } from '../realtime/realtime.module';
import { StockOpnamesController } from './stock-opnames.controller';
import { StockOpnamesService } from './stock-opnames.service';

@Module({
  imports: [RealtimeModule],
  controllers: [StockOpnamesController],
  providers: [StockOpnamesService],
})
export class StockOpnamesModule {}

