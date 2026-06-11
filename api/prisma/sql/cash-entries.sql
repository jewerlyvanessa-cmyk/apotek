-- Tabel pencatatan kas cabang (jalankan sebagai owner DB / postgres)
CREATE TABLE IF NOT EXISTS public.cash_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id),
  branch_id UUID NOT NULL REFERENCES public.branches(id),
  entry_date DATE NOT NULL,
  type VARCHAR(20) NOT NULL,
  category VARCHAR(100),
  amount DECIMAL(18, 2) NOT NULL,
  notes TEXT,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cash_entries_branch_date
  ON public.cash_entries (tenant_id, branch_id, entry_date);

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.cash_entries TO apotikflow_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.cash_entries TO apotikflow_platform;
