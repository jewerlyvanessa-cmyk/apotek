import { IsOptional, IsString } from 'class-validator';
import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

export class ProcurementQueryDto extends PaginationQueryDto {
  @IsOptional()
  @IsString()
  status?: string;
}
