-- Partition awal: stock_movements (RANGE created_at per bulan)
-- Jalankan di maintenance window sebagai owner DB (postgres).
-- Prisma schema belum diubah — ini skrip manual opsional (scale-2).

BEGIN;

-- 1) Tabel baru (partitioned) — PK harus mencakup kolom partition
CREATE TABLE IF NOT EXISTS public.stock_movements_p (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id),
  branch_id UUID NOT NULL REFERENCES public.branches(id),
  medicine_id UUID NOT NULL REFERENCES public.medicines(id),
  batch_id UUID REFERENCES public.medicine_batches(id),
  movement_type VARCHAR(50) NOT NULL,
  quantity INT NOT NULL,
  reference_type VARCHAR(50),
  reference_id UUID,
  notes TEXT,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE INDEX IF NOT EXISTS idx_stock_movements_p_tenant_branch_created
  ON public.stock_movements_p (tenant_id, branch_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_stock_movements_p_created
  ON public.stock_movements_p (created_at);

-- 2) Partisi bulanan: 3 bulan lalu s/d 3 bulan depan (sesuaikan tanggal)
CREATE TABLE IF NOT EXISTS public.stock_movements_p_2026_03
  PARTITION OF public.stock_movements_p
  FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE IF NOT EXISTS public.stock_movements_p_2026_04
  PARTITION OF public.stock_movements_p
  FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE IF NOT EXISTS public.stock_movements_p_2026_05
  PARTITION OF public.stock_movements_p
  FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

CREATE TABLE IF NOT EXISTS public.stock_movements_p_2026_06
  PARTITION OF public.stock_movements_p
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

CREATE TABLE IF NOT EXISTS public.stock_movements_p_2026_07
  PARTITION OF public.stock_movements_p
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');

CREATE TABLE IF NOT EXISTS public.stock_movements_p_2026_08
  PARTITION OF public.stock_movements_p
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

CREATE TABLE IF NOT EXISTS public.stock_movements_p_default
  PARTITION OF public.stock_movements_p DEFAULT;

-- 3) Salin data dari tabel lama (jika ada)
INSERT INTO public.stock_movements_p (
  id, tenant_id, branch_id, medicine_id, batch_id,
  movement_type, quantity, reference_type, reference_id,
  notes, created_by, created_at
)
SELECT
  id, tenant_id, branch_id, medicine_id, batch_id,
  movement_type, quantity, reference_type, reference_id,
  notes, created_by, created_at
FROM public.stock_movements
ON CONFLICT DO NOTHING;

-- 4) Swap nama (hentikan API dulu)
-- ALTER TABLE public.stock_movements RENAME TO stock_movements_legacy;
-- ALTER TABLE public.stock_movements_p RENAME TO stock_movements;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.stock_movements TO apotikflow_app;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.stock_movements TO apotikflow_platform;

COMMIT;

-- 5) Job bulanan: buat partisi berikutnya (contoh Juni 2026)
-- CREATE TABLE IF NOT EXISTS public.stock_movements_p_2026_09
--   PARTITION OF public.stock_movements
--   FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
