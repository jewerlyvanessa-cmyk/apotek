import { Type } from 'class-transformer';
import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateCashEntryDto {
  @IsIn(['CASH_IN', 'CASH_OUT'])
  type: 'CASH_IN' | 'CASH_OUT';

  @Type(() => Number)
  @IsNumber()
  @Min(0.01)
  amount: number;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  category?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;

  /** Tanggal buku YYYY-MM-DD — default hari ini */
  @IsOptional()
  @IsString()
  entry_date?: string;

  @IsOptional()
  @IsUUID()
  branch_id?: string;
}
