import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  MinLength,
} from 'class-validator';
import { LicenseType } from '../license.types';

export class GenerateLicenseDto {
  @IsString()
  @MinLength(2)
  customer: string;

  @IsOptional()
  @IsIn(['perpetual', 'subscription'])
  type?: LicenseType;

  /** Paket on-prem (starter, professional, enterprise, custom). */
  @IsOptional()
  @IsString()
  plan?: string;

  /** Kode tenant untuk mengunci lisensi (on-prem). */
  @IsOptional()
  @IsString()
  tenant_code?: string;

  /** Ambil kode tenant dari DB platform. */
  @IsOptional()
  @IsUUID()
  tenant_id?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  max_branches?: number;

  /** Masa berlaku lisensi dalam hari (kosong = tanpa kedaluwarsa). */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  days?: number;
}
