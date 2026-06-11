import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { SUBSCRIPTION_PLANS } from '../../license/license-plans';

const PLAN_IDS = SUBSCRIPTION_PLANS.map((p) => p.id);

export class BillingWebhookDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  tenant_code: string;

  @IsString()
  @IsIn(['PAID', 'FAILED', 'PENDING'])
  status: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  @IsIn(PLAN_IDS)
  plan?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  extend_days?: number;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  reference?: string;

  @IsOptional()
  @Type(() => Number)
  @Min(0)
  amount?: number;
}
