import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { createAdapter } from '@socket.io/redis-adapter';
import Redis from 'ioredis';
import { Server, Socket } from 'socket.io';
import {
  OrderEventPayload,
  ExpiredBatchPayload,
  PaymentEventPayload,
  StockUpdatedPayload,
  SubscriptionWarningPayload,
} from '../modules/realtime/realtime.service';

interface SocketUser {
  sub: string;
  tenantId: string;
  branchId?: string;
  role: string;
}

@WebSocketGateway({
  cors: { origin: '*' },
  transports: ['websocket', 'polling'],
})
export class EventsGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(EventsGateway.name);

  constructor(
    private jwt: JwtService,
    private config: ConfigService,
  ) {}

  async afterInit(server: Server) {
    const redisUrl = this.config.get<string>('REDIS_URL')?.trim();
    if (!redisUrl) return;

    try {
      const pub = new Redis(redisUrl);
      const sub = pub.duplicate();
      server.adapter(createAdapter(pub, sub));
      this.logger.log('Socket.IO Redis adapter aktif (multi-instance)');
    } catch (err) {
      this.logger.warn(
        `Redis adapter gagal — mode single-instance: ${err instanceof Error ? err.message : err}`,
      );
    }
  }

  async handleConnection(client: Socket) {
    try {
      const token =
        (client.handshake.auth?.token as string) ||
        (client.handshake.headers?.authorization as string)?.replace(
          'Bearer ',
          '',
        );

      if (!token) {
        client.disconnect();
        return;
      }

      const payload = await this.jwt.verifyAsync<SocketUser>(token);
      client.data.user = payload;

      client.join(`tenant:${payload.tenantId}`);
      if (payload.branchId) {
        client.join(`branch:${payload.branchId}`);
      }

      this.logger.log(
        `Client connected: ${client.id} tenant=${payload.tenantId} branch=${payload.branchId ?? 'all'}`,
      );
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Client disconnected: ${client.id}`);
  }

  broadcastStockUpdated(
    tenantId: string,
    branchId: string,
    payload: StockUpdatedPayload,
  ) {
    this.server.to(`branch:${branchId}`).emit('stock.updated', payload);
    this.server.to(`tenant:${tenantId}`).emit('stock.updated', payload);
  }

  broadcastStockLow(
    tenantId: string,
    branchId: string,
    payload: StockUpdatedPayload,
  ) {
    this.server.to(`branch:${branchId}`).emit('stock.low', payload);
    this.server.to(`tenant:${tenantId}`).emit('stock.low', payload);
  }

  broadcastOrderCreated(
    tenantId: string,
    branchId: string,
    payload: OrderEventPayload,
  ) {
    this.server.to(`branch:${branchId}`).emit('order.created', payload);
    this.server.to(`tenant:${tenantId}`).emit('order.created', payload);
  }

  broadcastOrderUpdated(
    tenantId: string,
    branchId: string,
    payload: OrderEventPayload,
  ) {
    this.server.to(`branch:${branchId}`).emit('order.updated', payload);
    this.server.to(`tenant:${tenantId}`).emit('order.updated', payload);
  }

  broadcastPaymentCompleted(
    tenantId: string,
    branchId: string,
    payload: PaymentEventPayload,
  ) {
    this.server.to(`branch:${branchId}`).emit('payment.completed', payload);
    this.server.to(`tenant:${tenantId}`).emit('payment.completed', payload);
  }

  broadcastExpired(
    tenantId: string,
    branchId: string,
    payload: ExpiredBatchPayload,
  ) {
    this.server.to(`branch:${branchId}`).emit('batch.expired', payload);
    this.server.to(`tenant:${tenantId}`).emit('batch.expired', payload);
  }

  broadcastSubscriptionWarning(
    tenantId: string,
    payload: SubscriptionWarningPayload,
  ) {
    this.server.to(`tenant:${tenantId}`).emit('subscription.warning', payload);
  }
}
