import { Prisma } from '@prisma/client';

export const DEFAULT_MEDICINE_UNITS = [
  'STRIP',
  'PCS',
  'BOTOL',
  'BOX',
  'TUBE',
  'SACHET',
] as const;

type MedicineUnitDb = {
  medicineUnit: {
    upsert: (args: {
      where: { tenantId_name: { tenantId: string; name: string } };
      create: Prisma.MedicineUnitCreateInput;
      update: Prisma.MedicineUnitUpdateInput;
    }) => Promise<{ id: string; name: string }>;
  };
};

export async function ensureDefaultMedicineUnits(
  db: MedicineUnitDb,
  tenantId: string,
) {
  for (const name of DEFAULT_MEDICINE_UNITS) {
    await db.medicineUnit.upsert({
      where: { tenantId_name: { tenantId, name } },
      create: {
        tenant: { connect: { id: tenantId } },
        name,
      },
      update: {},
    });
  }
}

export function normalizeMedicineUnitName(raw: string): string {
  return raw.trim().toUpperCase();
}
