import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsInt,
  IsOptional,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';

export class TransferItemDto {
  @IsUUID()
  medicine_id: string;

  @IsOptional()
  @IsUUID()
  batch_id?: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  quantity: number;
}

export class CreateTransferStockDto {
  @IsUUID()
  from_branch_id: string;

  @IsUUID()
  to_branch_id: string;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => TransferItemDto)
  items: TransferItemDto[];
}

