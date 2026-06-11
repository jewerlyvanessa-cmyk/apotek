import { IsUUID } from 'class-validator';
import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

export class TenantBranchesQueryDto extends PaginationQueryDto {
  @IsUUID()
  tenant_id: string;
}
