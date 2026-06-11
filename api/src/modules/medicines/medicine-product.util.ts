import { BadRequestException } from '@nestjs/common';

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
