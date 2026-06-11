import { IsString, MinLength } from 'class-validator';

export class ActivateLicenseDto {
  @IsString()
  @MinLength(20)
  license_key: string;
}
