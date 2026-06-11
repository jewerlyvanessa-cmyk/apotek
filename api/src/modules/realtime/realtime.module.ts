import { Module } from '@nestjs/common';
import { WebsocketModule } from '../../websocket/websocket.module';
import { RealtimeService } from './realtime.service';

@Module({
  imports: [WebsocketModule],
  providers: [RealtimeService],
  exports: [RealtimeService],
})
export class RealtimeModule {}
