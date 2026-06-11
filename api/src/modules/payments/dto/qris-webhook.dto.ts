import { IsNumber, IsString, IsUUID, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class QrisWebhookDto {
  @IsUUID()
  tenant_id: string;

  @IsUUID()
  order_id: string;

  @IsString()
  reference_number: string;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  amount: number;

  @IsString()
  status: 'PAID' | 'FAILED' | 'EXPIRED';
}

