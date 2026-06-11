import { Type } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';

export class StockMutationDto {
  @IsUUID()
  medicine_id: string;

  @IsOptional()
  @IsUUID()
  branch_id?: string;

  @IsOptional()
  @IsUUID()
  batch_id?: string;

  @IsString()
  movement_type: 'ADJUSTMENT' | 'PURCHASE' | 'SALE' | 'TRANSFER' | 'CANCEL' | 'RETURN';

  @Type(() => Number)
  @IsInt()
  quantity: number;

  @IsOptional()
  @IsString()
  notes?: string;
}

export class StockAdjustmentDto {
  @IsUUID()
  medicine_id: string;

  @IsOptional()
  @IsUUID()
  branch_id?: string;

  @IsOptional()
  @IsUUID()
  batch_id?: string;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  quantity: number;

  @IsOptional()
  @IsString()
  notes?: string;
}
