import { BadRequestException } from '@nestjs/common';
import { DrugClassification } from '../../common/constants/drug-classification';

export function assertPrescriptionForType(
  allowsPrescription: boolean,
  requiresPrescription?: boolean,
) {
  if (requiresPrescription && !allowsPrescription) {
    throw new BadRequestException(
      'Butuh resep hanya berlaku untuk tipe produk yang mendukung resep',
    );
  }
}

export function assertDrugClassificationForType(
  allowsPrescription: boolean,
  drugClassification?: DrugClassification | null,
) {
  if (drugClassification && !allowsPrescription) {
    throw new BadRequestException(
      'Golongan obat hanya berlaku untuk tipe produk obat',
    );
  }
}
