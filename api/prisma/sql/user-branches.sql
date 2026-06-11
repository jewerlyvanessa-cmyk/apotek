-- Penugasan multi-cabang per user (jalankan sekali pada DB yang sudah ada)
CREATE TABLE IF NOT EXISTS public.user_branches (
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  branch_id UUID NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, branch_id)
);

-- Migrasi cabang tunggal lama → junction
INSERT INTO public.user_branches (user_id, branch_id)
SELECT id, branch_id FROM public.users
WHERE branch_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- Hak akses role API (sama seperti tabel tenant lainnya)
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.user_branches TO apotikflow_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.user_branches TO apotikflow_platform;
