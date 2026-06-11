import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  MinLength,
} from 'class-validator';

export class MedicineBatchDto {
  @IsString()
  @MinLength(1)
  batch_number: string;

  @IsOptional()
  @IsDateString()
  expired_date?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  buy_price?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  sell_price?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  initial_quantity?: number;
}

export class CreateMedicineDto {
  @IsString()
  @MinLength(2)
  name: string;

  @IsOptional()
  @IsString()
  barcode?: string;

  @IsOptional()
  @IsString()
  sku?: string;

  @IsOptional()
  @IsUUID()
  category_id?: string;

  @IsOptional()
  @IsUUID()
  supplier_id?: string;

  @IsOptional()
  @IsString()
  unit?: string;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  buy_price: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  sell_price: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  min_stock?: number;

  @IsOptional()
  @IsUUID()
  product_type_id?: string;

  /** @deprecated gunakan product_type_id */
  @IsOptional()
  @IsString()
  product_type?: string;

  @IsOptional()
  @IsBoolean()
  requires_prescription?: boolean;

  @IsOptional()
  @IsUUID()
  branch_id?: string;

  @IsOptional()
  batch?: MedicineBatchDto;
}
