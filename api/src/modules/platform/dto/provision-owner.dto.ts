import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';

export class ProvisionOwnerDto {
  @IsString()
  full_name: string;

  @IsEmail()
  email: string;

  @IsString()
  @MinLength(6)
  password: string;

  @IsOptional()
  @IsString()
  phone?: string;
}
