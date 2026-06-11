-- Backfill setelah prisma db push / migrate.
-- Jalankan sekali: psql $DATABASE_URL -f prisma/sql/stock-locations-backfill.sql

DO $$
DECLARE
  b RECORD;
  main_id UUID;
BEGIN
  FOR b IN SELECT id, stock_mode, is_central_warehouse FROM branches LOOP
    IF NOT EXISTS (SELECT 1 FROM stock_locations WHERE branch_id = b.id) THEN
      IF b.is_central_warehouse OR b.stock_mode = 'SIMPLE' THEN
        INSERT INTO stock_locations (id, branch_id, code, name, is_sellable, sort_order, created_at)
        VALUES (gen_random_uuid(), b.id, 'MAIN', 'Stok Utama', true, 0, NOW())
        RETURNING id INTO main_id;
      ELSE
        INSERT INTO stock_locations (id, branch_id, code, name, is_sellable, sort_order, created_at)
        VALUES (gen_random_uuid(), b.id, 'BACK', 'Gudang Cabang', false, 0, NOW());
        INSERT INTO stock_locations (id, branch_id, code, name, is_sellable, sort_order, created_at)
        VALUES (gen_random_uuid(), b.id, 'FRONT', 'Etalase', true, 1, NOW())
        RETURNING id INTO main_id;
      END IF;
    END IF;

    SELECT id INTO main_id
    FROM stock_locations
    WHERE branch_id = b.id AND code = 'MAIN'
    LIMIT 1;

    IF main_id IS NULL THEN
      SELECT id INTO main_id
      FROM stock_locations
      WHERE branch_id = b.id
      ORDER BY sort_order
      LIMIT 1;
    END IF;

    IF main_id IS NOT NULL THEN
      UPDATE stocks SET location_id = main_id WHERE branch_id = b.id AND location_id IS NULL;
    END IF;
  END LOOP;
END $$;
