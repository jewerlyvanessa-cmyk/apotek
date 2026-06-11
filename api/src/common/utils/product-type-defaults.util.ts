import { Prisma } from '@prisma/client';

export const DEFAULT_PRODUCT_TYPES = [
  {
    code: 'DRUG',
    name: 'Obat',
    allowsPrescription: true,
    sortOrder: 0,
  },
  {
    code: 'HEALTH',
    name: 'Produk kesehatan',
    allowsPrescription: false,
    sortOrder: 1,
  },
  {
    code: 'COMMERCIAL',
    name: 'Produk komersial',
    allowsPrescription: false,
    sortOrder: 2,
  },
] as const;

type ProductTypeDb = {
  productTypeDefinition: {
    findFirst: (args: {
      where: { tenantId: string; code?: string; id?: string; isActive?: boolean };
    }) => Promise<{ id: string; code: string; allowsPrescription: boolean } | null>;
    upsert: (args: {
      where: { tenantId_code: { tenantId: string; code: string } };
      create: Prisma.ProductTypeDefinitionCreateInput;
      update: Prisma.ProductTypeDefinitionUpdateInput;
    }) => Promise<{ id: string }>;
  };
};

export async function ensureDefaultProductTypes(
  db: ProductTypeDb,
  tenantId: string,
) {
  for (const row of DEFAULT_PRODUCT_TYPES) {
    await db.productTypeDefinition.upsert({
      where: { tenantId_code: { tenantId, code: row.code } },
      create: {
        tenant: { connect: { id: tenantId } },
        code: row.code,
        name: row.name,
        allowsPrescription: row.allowsPrescription,
        sortOrder: row.sortOrder,
      },
      update: {},
    });
  }
}

export async function resolveProductTypeId(
  db: ProductTypeDb,
  tenantId: string,
  input?: { product_type_id?: string; product_type?: string },
): Promise<{ id: string; code: string; allowsPrescription: boolean }> {
  await ensureDefaultProductTypes(db, tenantId);

  if (input?.product_type_id) {
    const byId = await db.productTypeDefinition.findFirst({
      where: { tenantId, id: input.product_type_id, isActive: true },
    });
    if (!byId) {
      throw new Error('Tipe produk tidak ditemukan');
    }
    return byId;
  }

  const code = input?.product_type?.trim().toUpperCase() || 'DRUG';
  const byCode = await db.productTypeDefinition.findFirst({
    where: { tenantId, code, isActive: true },
  });
  if (!byCode) {
    throw new Error(`Tipe produk ${code} tidak ditemukan`);
  }
  return byCode;
}
