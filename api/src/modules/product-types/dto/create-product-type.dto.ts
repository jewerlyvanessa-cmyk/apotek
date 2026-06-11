import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Min,
  MinLength,
} from 'class-validator';

export class CreateProductTypeDto {
  @IsString()
  @MinLength(2)
  @Matches(/^[A-Z0-9_]+$/, {
    message: 'Kode hanya huruf besar, angka, dan underscore',
  })
  code: string;

  @IsString()
  @MinLength(2)
  name: string;

  @IsOptional()
  @IsBoolean()
  allows_prescription?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  sort_order?: number;
}
