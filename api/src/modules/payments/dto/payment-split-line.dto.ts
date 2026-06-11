import { Type } from 'class-transformer';
import {
  IsNumber,
  IsOptional,
  IsString,
  Min,
  ValidateIf,
} from 'class-validator';

export class PaymentSplitLineDto {
  @IsString()
  payment_method: 'CASH' | 'QRIS' | 'TRANSFER' | 'EDC';

  @Type(() => Number)
  @IsNumber()
  @Min(0.01)
  amount: number;

  @ValidateIf((o) => o.payment_method === 'CASH')
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  amount_received?: number;

  @IsOptional()
  @IsString()
  reference_number?: string;

  @ValidateIf(
    (o) => o.payment_method === 'QRIS' || o.payment_method === 'TRANSFER',
  )
  @IsString()
  proof_image_url?: string;
}
