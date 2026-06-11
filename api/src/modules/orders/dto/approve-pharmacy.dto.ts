import { IsOptional, IsString } from 'class-validator';

export class ApprovePharmacyDto {
  @IsOptional()
  @IsString()
  pharmacist_notes?: string;
}
