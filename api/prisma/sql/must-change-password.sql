-- Kolom wajib ganti password (akun seed / owner baru on-prem)
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT false;

-- Akun demo seed — wajib ganti saat go-live
UPDATE public.users
SET must_change_password = true
WHERE email IN ('superadmin@apotikflow.com', 'owner@apotikflow.com');
