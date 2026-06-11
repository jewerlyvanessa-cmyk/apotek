import { Type } from 'class-transformer';
import { IsISO8601, IsOptional, IsString, IsUUID } from 'class-validator';
import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

export class StockMovementQueryDto extends PaginationQueryDto {
  @IsOptional()
  @IsUUID()
  branch_id?: string;

  @IsOptional()
  @IsUUID()
  medicine_id?: string;

  @IsOptional()
  @IsString()
  movement_type?: string;

  @IsOptional()
  @IsString()
  reference_type?: string;

  @IsOptional()
  @IsUUID()
  reference_id?: string;

  @IsOptional()
  @Type(() => String)
  @IsISO8601()
  date_from?: string;

  @IsOptional()
  @Type(() => String)
  @IsISO8601()
  date_to?: string;
}

