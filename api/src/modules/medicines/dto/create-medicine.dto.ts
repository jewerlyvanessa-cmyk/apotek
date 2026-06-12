import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  MinLength,
} from 'class-validator';
import { DrugClassification } from '../../../common/constants/drug-classification';

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
  @IsString()
  composition?: string;

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
  @IsEnum(DrugClassification)
  drug_classification?: DrugClassification | null;

  /** @deprecated gunakan drug_classification */
  @IsOptional()
  @IsBoolean()
  requires_prescription?: boolean;

  @IsOptional()
  @IsUUID()
  branch_id?: string;

  @IsOptional()
  batch?: MedicineBatchDto;
}
