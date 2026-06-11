import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { PrescriptionDto } from './prescription.dto';

export class OrderItemDto {
  @IsUUID()
  medicine_id: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  quantity: number;

  /** Petunjuk penggunaan per item (wajib untuk obat bertanda resep). */
  @IsOptional()
  @IsString()
  @MaxLength(500)
  usage_instructions?: string;
}

export class CreateOrderDto {
  @IsOptional()
  @IsUUID()
  customer_id?: string;

  @IsOptional()
  @IsString()
  customer_name?: string;

  @IsOptional()
  @IsString()
  customer_phone?: string;

  /** @deprecated Gunakan objek `prescription`; tetap didukung untuk catatan bebas. */
  @IsOptional()
  @IsString()
  prescription_notes?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => PrescriptionDto)
  prescription?: PrescriptionDto;

  /** Paksa alur telaah apoteker meski tanpa obat bertanda resep. */
  @IsOptional()
  @IsBoolean()
  has_prescription?: boolean;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => OrderItemDto)
  items: OrderItemDto[];
}
