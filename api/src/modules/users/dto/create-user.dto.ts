import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsEmail,
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { UserRole } from '@prisma/client';
import { BranchAssignmentDto } from './branch-assignment.dto';

export class CreateUserDto {
  @IsString()
  full_name: string;

  @IsEmail()
  email: string;

  @IsString()
  @MinLength(6)
  password: string;

  /** Peran tenant-wide: Owner, Manajer Pusat. */
  @IsOptional()
  @IsArray()
  @IsEnum(UserRole, { each: true })
  global_roles?: UserRole[];

  /** Penugasan peran per cabang. */
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BranchAssignmentDto)
  branch_assignments?: BranchAssignmentDto[];

  /** @deprecated Gunakan global_roles + branch_assignments */
  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @IsEnum(UserRole, { each: true })
  roles?: UserRole[];

  @IsOptional()
  @IsEnum(UserRole)
  active_role?: UserRole;

  @IsOptional()
  @IsUUID()
  branch_id?: string;

  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  branch_ids?: string[];

  @IsOptional()
  @IsString()
  phone?: string;
}
