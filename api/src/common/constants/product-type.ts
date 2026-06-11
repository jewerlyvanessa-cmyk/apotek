export enum ProductType {
  DRUG = 'DRUG',
  HEALTH = 'HEALTH',
  COMMERCIAL = 'COMMERCIAL',
}

export const PRODUCT_TYPE_LABELS: Record<ProductType, string> = {
  [ProductType.DRUG]: 'Obat',
  [ProductType.HEALTH]: 'Produk kesehatan',
  [ProductType.COMMERCIAL]: 'Produk komersial',
};

export function normalizeProductType(value?: string): ProductType {
  const upper = value?.trim().toUpperCase();
  if (upper === ProductType.HEALTH) return ProductType.HEALTH;
  if (upper === ProductType.COMMERCIAL) return ProductType.COMMERCIAL;
  return ProductType.DRUG;
}

export function assertPrescriptionAllowed(
  productType: ProductType,
  requiresPrescription?: boolean,
) {
  if (requiresPrescription && productType !== ProductType.DRUG) {
    throw new Error(
      'Butuh resep hanya berlaku untuk tipe produk Obat (DRUG)',
    );
  }
}
