import { IsOptional, IsString, IsUUID } from 'class-validator';
import { PaginationQueryDto } from '../../../common/dto/pagination.dto';

export class MedicineQueryDto extends PaginationQueryDto {
  @IsOptional()
  @IsUUID()
  category_id?: string;

  @IsOptional()
  @IsString()
  barcode?: string;

  @IsOptional()
  @IsUUID()
  product_type_id?: string;

  /** Filter by kode tipe (DRUG, HEALTH, ...) */
  @IsOptional()
  @IsString()
  product_type?: string;
}
