import { IsOptional, IsString, IsUUID } from 'class-validator';

export class CreateStockOpnameDto {
  @IsOptional()
  @IsUUID()
  branch_id?: string;

  @IsOptional()
  @IsString()
  notes?: string;
}

