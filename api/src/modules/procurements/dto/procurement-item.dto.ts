import { Type } from 'class-transformer';
import {
  IsDateString,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';

export class ProcurementItemDto {
  @IsUUID()
  medicine_id: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  quantity: number;

  @IsOptional()
  @IsString()
  batch_number?: string;

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
}
