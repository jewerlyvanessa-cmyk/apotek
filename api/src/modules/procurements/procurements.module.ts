import { Module } from '@nestjs/common';
import { RealtimeModule } from '../realtime/realtime.module';
import { ProcurementsController } from './procurements.controller';
import { ProcurementsService } from './procurements.service';

@Module({
  imports: [RealtimeModule],
  controllers: [ProcurementsController],
  providers: [ProcurementsService],
  exports: [ProcurementsService],
})
export class ProcurementsModule {}
