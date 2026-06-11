import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsEmail,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { ProvisionOwnerDto } from './provision-owner.dto';

export class CreateTenantDto {
  @IsString()
  @MaxLength(255)
  name: string;

  @IsString()
  @MaxLength(50)
  code: string;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  phone?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  address?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  subscription_plan?: string;

  /** Buat gudang pusat default (PUSAT). Default true jika owner disertakan. */
  @IsOptional()
  @IsBoolean()
  create_central_warehouse?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  central_branch_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  central_branch_code?: string;

  /** Akun OWNER pertama — wajib agar tenant bisa dioperasikan. */
  @IsOptional()
  @ValidateNested()
  @Type(() => ProvisionOwnerDto)
  owner?: ProvisionOwnerDto;
}
