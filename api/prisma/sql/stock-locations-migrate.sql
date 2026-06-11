-- Migrasi mode stok cabang (jalankan sekali sebelum prisma db push jika ada data stocks).
-- psql $DATABASE_URL -f prisma/sql/stock-locations-migrate.sql

DO $$ BEGIN
  CREATE TYPE branch_stock_mode AS ENUM ('SIMPLE', 'WAREHOUSE_ETALASE');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE branches
  ADD COLUMN IF NOT EXISTS stock_mode branch_stock_mode NOT NULL DEFAULT 'SIMPLE';

CREATE TABLE IF NOT EXISTS stock_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  code VARCHAR(20) NOT NULL,
  name VARCHAR(100) NOT NULL,
  is_sellable BOOLEAN NOT NULL DEFAULT false,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE (branch_id, code)
);

CREATE TABLE IF NOT EXISTS stock_internal_moves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  branch_id UUID NOT NULL REFERENCES branches(id),
  from_location_id UUID NOT NULL REFERENCES stock_locations(id),
  to_location_id UUID NOT NULL REFERENCES stock_locations(id),
  status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',
  notes TEXT,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_internal_moves_branch_created
  ON stock_internal_moves(branch_id, created_at);

CREATE TABLE IF NOT EXISTS stock_internal_move_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  move_id UUID NOT NULL REFERENCES stock_internal_moves(id) ON DELETE CASCADE,
  medicine_id UUID NOT NULL REFERENCES medicines(id),
  batch_id UUID REFERENCES medicine_batches(id),
  quantity INT NOT NULL
);

ALTER TABLE stocks ADD COLUMN IF NOT EXISTS location_id UUID REFERENCES stock_locations(id);

DO $$
DECLARE
  b RECORD;
  loc_id UUID;
BEGIN
  FOR b IN SELECT id, stock_mode::text AS stock_mode, is_central_warehouse FROM branches LOOP
    IF NOT EXISTS (SELECT 1 FROM stock_locations WHERE branch_id = b.id) THEN
      IF b.is_central_warehouse OR b.stock_mode = 'SIMPLE' THEN
        INSERT INTO stock_locations (branch_id, code, name, is_sellable, sort_order)
        VALUES (b.id, 'MAIN', 'Stok Utama', true, 0);
      ELSE
        INSERT INTO stock_locations (branch_id, code, name, is_sellable, sort_order)
        VALUES (b.id, 'BACK', 'Gudang Cabang', false, 0);
        INSERT INTO stock_locations (branch_id, code, name, is_sellable, sort_order)
        VALUES (b.id, 'FRONT', 'Etalase', true, 1);
      END IF;
    END IF;

    SELECT id INTO loc_id FROM stock_locations
    WHERE branch_id = b.id AND code = 'MAIN' LIMIT 1;
    IF loc_id IS NULL THEN
      SELECT id INTO loc_id FROM stock_locations
      WHERE branch_id = b.id AND code = 'BACK' LIMIT 1;
    END IF;
    IF loc_id IS NOT NULL THEN
      UPDATE stocks SET location_id = loc_id WHERE branch_id = b.id AND location_id IS NULL;
    END IF;
  END LOOP;
END $$;

ALTER TABLE stocks ALTER COLUMN location_id SET NOT NULL;

DO $$ BEGIN
  ALTER TABLE stocks DROP CONSTRAINT IF EXISTS stocks_branch_id_medicine_id_batch_id_key;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS stocks_branch_location_medicine_batch_key
  ON stocks (branch_id, location_id, medicine_id, COALESCE(batch_id, '00000000-0000-0000-0000-000000000000'::uuid));
