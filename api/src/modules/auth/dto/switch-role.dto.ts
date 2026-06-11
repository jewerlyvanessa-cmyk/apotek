import { IsEnum } from 'class-validator';
import { UserRole } from '@prisma/client';

export class SwitchRoleDto {
  @IsEnum(UserRole)
  role: UserRole;
}
