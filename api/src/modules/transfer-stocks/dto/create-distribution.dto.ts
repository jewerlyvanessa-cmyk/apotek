import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsUUID,
  ValidateNested,
} from 'class-validator';
import { TransferItemDto } from './create-transfer-stock.dto';

export class CreateDistributionDto {
  @IsUUID()
  to_branch_id: string;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => TransferItemDto)
  items: TransferItemDto[];
}
