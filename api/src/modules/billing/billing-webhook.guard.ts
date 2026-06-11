import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { timingSafeEqual } from 'crypto';
import type { Request } from 'express';

@Injectable()
export class BillingWebhookGuard implements CanActivate {
  constructor(private config: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const secret = this.config.get<string>('BILLING_WEBHOOK_SECRET')?.trim();
    const nodeEnv = (this.config.get<string>('NODE_ENV') ?? 'development').trim();

    if (!secret) {
      if (nodeEnv === 'production') {
        throw new UnauthorizedException(
          'Billing webhook secret tidak dikonfigurasi',
        );
      }
      return true;
    }

    const req = context.switchToHttp().getRequest<Request>();
    const header = req.headers['x-webhook-secret'];
    if (typeof header !== 'string' || !this.safeEqual(header, secret)) {
      throw new UnauthorizedException('Webhook secret tidak valid');
    }
    return true;
  }

  private safeEqual(a: string, b: string): boolean {
    const bufA = Buffer.from(a);
    const bufB = Buffer.from(b);
    if (bufA.length !== bufB.length) return false;
    return timingSafeEqual(bufA, bufB);
  }
}
