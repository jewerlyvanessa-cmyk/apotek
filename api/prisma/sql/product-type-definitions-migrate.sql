-- Migrasi tipe produk tenant + relasi medicines.product_type_id
-- Jalankan: psql "$DATABASE_URL" -f prisma/sql/product-type-definitions-migrate.sql

CREATE TABLE IF NOT EXISTS product_type_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  code VARCHAR(50) NOT NULL,
  name VARCHAR(255) NOT NULL,
  allows_prescription BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, code)
);

ALTER TABLE medicine_categories
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

DO $$
DECLARE
  t RECORD;
  drug_id UUID;
  health_id UUID;
  commercial_id UUID;
BEGIN
  FOR t IN SELECT id FROM tenants LOOP
    INSERT INTO product_type_definitions (tenant_id, code, name, allows_prescription, sort_order)
    VALUES (t.id, 'DRUG', 'Obat', true, 0)
    ON CONFLICT (tenant_id, code) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO drug_id;
    IF drug_id IS NULL THEN
      SELECT id INTO drug_id FROM product_type_definitions
      WHERE tenant_id = t.id AND code = 'DRUG';
    END IF;

    INSERT INTO product_type_definitions (tenant_id, code, name, allows_prescription, sort_order)
    VALUES (t.id, 'HEALTH', 'Produk kesehatan', false, 1)
    ON CONFLICT (tenant_id, code) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO health_id;
    IF health_id IS NULL THEN
      SELECT id INTO health_id FROM product_type_definitions
      WHERE tenant_id = t.id AND code = 'HEALTH';
    END IF;

    INSERT INTO product_type_definitions (tenant_id, code, name, allows_prescription, sort_order)
    VALUES (t.id, 'COMMERCIAL', 'Produk komersial', false, 2)
    ON CONFLICT (tenant_id, code) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO commercial_id;
    IF commercial_id IS NULL THEN
      SELECT id INTO commercial_id FROM product_type_definitions
      WHERE tenant_id = t.id AND code = 'COMMERCIAL';
    END IF;
  END LOOP;
END $$;

ALTER TABLE medicines ADD COLUMN IF NOT EXISTS product_type_id UUID;

UPDATE medicines m
SET product_type_id = ptd.id
FROM product_type_definitions ptd
WHERE ptd.tenant_id = m.tenant_id
  AND ptd.code = UPPER(m.product_type::text)
  AND m.product_type_id IS NULL;

UPDATE medicines m
SET product_type_id = ptd.id
FROM product_type_definitions ptd
WHERE ptd.tenant_id = m.tenant_id
  AND ptd.code = 'DRUG'
  AND m.product_type_id IS NULL;

ALTER TABLE medicines
  ALTER COLUMN product_type_id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'medicines_product_type_id_fkey'
  ) THEN
    ALTER TABLE medicines
      ADD CONSTRAINT medicines_product_type_id_fkey
      FOREIGN KEY (product_type_id) REFERENCES product_type_definitions(id);
  END IF;
END $$;

ALTER TABLE medicines DROP COLUMN IF EXISTS product_type;

DROP TYPE IF EXISTS product_type;
