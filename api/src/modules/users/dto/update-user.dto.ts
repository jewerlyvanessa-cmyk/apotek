import { Transform, Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  ValidateNested,
} from 'class-validator';
import { UserRole } from '@prisma/client';
import { BranchAssignmentDto } from './branch-assignment.dto';

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  full_name?: string;

  @IsOptional()
  @IsArray()
  @IsEnum(UserRole, { each: true })
  global_roles?: UserRole[];

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BranchAssignmentDto)
  branch_assignments?: BranchAssignmentDto[];

  @IsOptional()
  @IsUUID()
  branch_id?: string | null;

  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  branch_ids?: string[];

  @IsOptional()
  @IsString()
  phone?: string | null;

  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true' || value === '1')
  @IsBoolean()
  is_active?: boolean;
}
