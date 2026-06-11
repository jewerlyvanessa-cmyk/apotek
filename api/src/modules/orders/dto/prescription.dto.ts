import { BadRequestException } from '@nestjs/common';
import { IsDateString, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

/** Data resep dokter pada order (wajib hanya jika order ditandai berresep). */
export class PrescriptionDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  prescription_number?: string;

  @IsOptional()
  @IsDateString()
  prescription_date?: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(255)
  doctor_name?: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(255)
  patient_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  patient_age?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  prescription_instructions?: string;

  /** Catatan tambahan (disimpan di prescription_notes). */
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;
}

export type ResolvedPrescription = {
  prescriptionNumber: string | null;
  prescriptionDate: Date | null;
  doctorName: string | null;
  patientName: string | null;
  patientAge: string | null;
  prescriptionInstructions: string | null;
  prescriptionNotes: string | null;
};

export function resolvePrescription(
  prescription?: PrescriptionDto,
  legacyNotes?: string,
): ResolvedPrescription {
  const p = prescription;
  const dateStr = p?.prescription_date?.trim();
  let prescriptionDate: Date | null = null;
  if (dateStr) {
    const parsed = new Date(dateStr);
    if (!Number.isNaN(parsed.getTime())) {
      prescriptionDate = parsed;
    }
  }

  return {
    prescriptionNumber: p?.prescription_number?.trim() || null,
    prescriptionDate,
    doctorName: p?.doctor_name?.trim() || null,
    patientName: p?.patient_name?.trim() || null,
    patientAge: p?.patient_age?.trim() || null,
    prescriptionInstructions: p?.prescription_instructions?.trim() || null,
    prescriptionNotes: p?.notes?.trim() || legacyNotes?.trim() || null,
  };
}

export function assertPrescriptionComplete(
  rx: ResolvedPrescription,
  needsPharmacyReview: boolean,
) {
  if (!needsPharmacyReview) return;

  const missing: string[] = [];
  if (!rx.prescriptionNumber) missing.push('nomor resep');
  if (!rx.prescriptionDate) missing.push('tanggal resep');
  if (!rx.doctorName) missing.push('nama dokter');
  if (!rx.patientName) missing.push('nama pasien');

  if (missing.length) {
    throw new BadRequestException(
      `Data resep wajib diisi: ${missing.join(', ')}`,
    );
  }
}
