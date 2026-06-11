import { ArrayMinSize, IsArray, IsEnum, IsOptional } from 'class-validator';
import { UserRole } from '@prisma/client';

export class UpdateRoleDto {
  @IsArray()
  @ArrayMinSize(1)
  @IsEnum(UserRole, { each: true })
  roles: UserRole[];

  @IsOptional()
  @IsEnum(UserRole)
  active_role?: UserRole;
}
