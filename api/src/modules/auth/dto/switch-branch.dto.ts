import { IsEnum, IsOptional, IsUUID } from 'class-validator';
import { UserRole } from '@prisma/client';

export class SwitchBranchDto {
  @IsUUID()
  branch_id: string;

  /** Peran aktif di cabang tujuan (wajib sesuai penugasan cabang). */
  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;
}
