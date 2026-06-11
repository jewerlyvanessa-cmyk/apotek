import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';

export class StockOpnameItemInputDto {
  @IsUUID()
  medicine_id: string;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  actual_qty: number;

  @IsOptional()
  @IsString()
  notes?: string;
}

export class UpsertOpnameItemsDto {
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => StockOpnameItemInputDto)
  items: StockOpnameItemInputDto[];
}

