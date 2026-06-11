import { Injectable } from '@nestjs/common';
import { EventsGateway } from '../../websocket/events.gateway';

export interface StockUpdatedPayload {
  medicine_id: string;
  branch_id: string;
  batch_id?: string | null;
  medicine_name?: string;
  quantity: number;
  reserved_quantity: number;
  available_quantity: number;
}

export interface OrderEventPayload {
  order_id: string;
  order_number?: string;
  status: string;
  total?: number;
  customer_name?: string | null;
}

export interface PaymentEventPayload {
  payment_id: string;
  order_id: string;
  order_number?: string;
  status: string;
  amount?: number;
}

export interface SubscriptionWarningPayload {
  tenant_code: string;
  tenant_name: string;
  subscription_plan?: string | null;
  subscription_expired_at: string;
  days_left: number;
}

export interface ExpiredBatchPayload {
  branch_id: string;
  medicine_id: string;
  medicine_name?: string;
  batch_id?: string | null;
  batch_number?: string;
  expired_date?: string | null;
  quantity?: number;
  days_left?: number | null;
}

@Injectable()
export class RealtimeService {
  constructor(private gateway: EventsGateway) {}

  emitStockUpdated(tenantId: string, branchId: string, payload: StockUpdatedPayload) {
    this.gateway.broadcastStockUpdated(tenantId, branchId, payload);
  }

  emitStockLow(tenantId: string, branchId: string, payload: StockUpdatedPayload) {
    this.gateway.broadcastStockLow(tenantId, branchId, payload);
  }

  emitOrderCreated(tenantId: string, branchId: string, payload: OrderEventPayload) {
    this.gateway.broadcastOrderCreated(tenantId, branchId, payload);
  }

  emitOrderUpdated(tenantId: string, branchId: string, payload: OrderEventPayload) {
    this.gateway.broadcastOrderUpdated(tenantId, branchId, payload);
  }

  emitPaymentCompleted(
    tenantId: string,
    branchId: string,
    payload: PaymentEventPayload,
  ) {
    this.gateway.broadcastPaymentCompleted(tenantId, branchId, payload);
  }

  emitExpired(tenantId: string, branchId: string, payload: ExpiredBatchPayload) {
    this.gateway.broadcastExpired(tenantId, branchId, payload);
  }

  emitSubscriptionWarning(tenantId: string, payload: SubscriptionWarningPayload) {
    this.gateway.broadcastSubscriptionWarning(tenantId, payload);
  }
}
