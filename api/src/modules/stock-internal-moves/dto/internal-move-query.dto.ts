import { IsOptional, IsUUID } from 'class-validator';
import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

export class InternalMoveQueryDto extends PaginationQueryDto {
  @IsOptional()
  @IsUUID()
  branch_id?: string;
}
