import { IsOptional, IsString } from 'class-validator';
import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

export class TransferQueryDto extends PaginationQueryDto {
  @IsOptional()
  @IsString()
  status?: string;

  @IsOptional()
  @IsString()
  from_branch_id?: string;

  @IsOptional()
  @IsString()
  to_branch_id?: string;

  @IsOptional()
  @IsString()
  transfer_type?: string;
}

