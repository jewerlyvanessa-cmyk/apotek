import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { SUBSCRIPTION_PLANS } from '../../license/license-plans';

const PLAN_IDS = SUBSCRIPTION_PLANS.map((p) => p.id);

export class RenewalIntentDto {
  @IsOptional()
  @IsString()
  @MaxLength(50)
  @IsIn(PLAN_IDS)
  plan?: string;
}
