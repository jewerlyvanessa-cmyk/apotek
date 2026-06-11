import { ArrayMinSize, IsArray, IsEnum, IsUUID } from 'class-validator';
import { UserRole } from '@prisma/client';

export class BranchAssignmentDto {
  @IsUUID()
  branch_id: string;

  @IsArray()
  @ArrayMinSize(1)
  @IsEnum(UserRole, { each: true })
  roles: UserRole[];
}
