import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';
import { SUBSCRIPTION_PLANS } from '../../license/license-plans';

const PLAN_IDS = SUBSCRIPTION_PLANS.map((p) => p.id);

export class ExtendTenantSubscriptionDto {
  @IsOptional()
  @IsString()
  @MaxLength(50)
  @IsIn(PLAN_IDS)
  plan?: string;

  /** Perpanjang N hari dari sekarang atau dari tanggal expired saat ini (mana yang lebih besar). */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  extend_days?: number;
}
