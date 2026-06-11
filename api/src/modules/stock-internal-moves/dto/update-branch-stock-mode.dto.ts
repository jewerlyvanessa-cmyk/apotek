import { BranchStockMode } from '@prisma/client';
import { IsEnum, IsIn, IsOptional } from 'class-validator';

export class UpdateBranchStockModeDto {
  @IsEnum(BranchStockMode)
  stock_mode!: BranchStockMode;

  /** Saat SIMPLE → WAREHOUSE_ETALASE: stok existing ke BACK (default) atau FRONT */
  @IsOptional()
  @IsIn(['BACK', 'FRONT'])
  move_existing_to?: 'BACK' | 'FRONT';
}
