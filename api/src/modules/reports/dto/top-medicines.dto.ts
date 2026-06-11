import { IsInt, IsOptional, IsString, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { ReportRangeDto } from './report-range.dto';

export class TopMedicinesDto extends ReportRangeDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limit?: number;

  @IsOptional()
  @IsString()
  order_by?: 'qty' | 'subtotal';
}

