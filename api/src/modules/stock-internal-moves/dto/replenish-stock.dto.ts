import { IsInt, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class ReplenishStockDto {
  @IsOptional()
  @IsUUID()
  branch_id?: string;

  @IsUUID()
  medicine_id!: string;

  @IsOptional()
  @IsUUID()
  batch_id?: string;

  @IsInt()
  @Min(1)
  quantity!: number;

  @IsOptional()
  @IsString()
  notes?: string;
}
