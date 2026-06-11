import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateIf,
  ValidateNested,
} from 'class-validator';
import { PaymentSplitLineDto } from './payment-split-line.dto';

export class PayOrderDto {
  @IsUUID()
  order_id: string;

  /** Diabaikan jika `splits` diisi (bayar campuran). */
  @ValidateIf((o) => !o.splits?.length)
  @IsString()
  payment_method?: 'CASH' | 'QRIS' | 'TRANSFER' | 'EDC';

  @ValidateIf((o) => !o.splits?.length)
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  amount?: number;

  /** Bayar campuran — jumlah `amount` harus sama dengan total order. */
  @IsOptional()
  @IsArray()
  @ArrayMinSize(2)
  @ValidateNested({ each: true })
  @Type(() => PaymentSplitLineDto)
  splits?: PaymentSplitLineDto[];

  /** Tunai: uang yang diterima dari pelanggan (wajib, >= amount). */
  @ValidateIf((o) => o.payment_method === 'CASH')
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  amount_received?: number;

  @IsOptional()
  @IsString()
  reference_number?: string;

  /** QRIS / Transfer: URL bukti bayar dari upload. */
  @ValidateIf((o) => o.payment_method === 'QRIS' || o.payment_method === 'TRANSFER')
  @IsString()
  proof_image_url?: string;
}
