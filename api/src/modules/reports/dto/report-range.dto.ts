import { IsDateString, IsOptional, IsString } from 'class-validator';

export class ReportRangeDto {
  @IsOptional()
  @IsDateString()
  date_from?: string;

  @IsOptional()
  @IsDateString()
  date_to?: string;

  @IsOptional()
  @IsString()
  branch_id?: string;
}

