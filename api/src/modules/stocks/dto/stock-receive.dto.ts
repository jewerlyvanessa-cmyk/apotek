import { Type } from 'class-transformer';
import {
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';

export class StockReceiveDto {
  @IsUUID()
  medicine_id: string;

  @IsOptional()
  @IsUUID()
  branch_id?: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  quantity: number;

  @IsOptional()
  @IsUUID()
  batch_id?: string;

  @ValidateIf((o) => !o.batch_id)
  @IsOptional()
  @IsString()
  @MinLength(1)
  batch_number?: string;

  @IsOptional()
  @IsDateString()
  expired_date?: string;

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsString()
  rack_position?: string;
}
