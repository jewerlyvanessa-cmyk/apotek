import { Type } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsString,
  Max,
  Min,
  MinLength,
} from 'class-validator';

export class DatabaseConnectionDto {
  @IsString()
  @MinLength(1)
  host: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(65535)
  port: number;

  @IsString()
  @MinLength(1)
  database: string;

  @IsString()
  @MinLength(1)
  user: string;

  @IsString()
  @MinLength(1)
  password: string;
}

export class DatabaseSetupDto extends DatabaseConnectionDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  admin_user?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  admin_password?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  app_user?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  app_password?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  platform_user?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  platform_password?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  migrate_user?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  migrate_password?: string;
}
