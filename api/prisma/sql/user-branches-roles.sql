-- Peran per cabang + peran global tenant
ALTER TABLE public.user_branches
  ADD COLUMN IF NOT EXISTS roles "UserRole"[] NOT NULL DEFAULT '{}';

-- Salin peran user lama ke setiap cabang yang ditugaskan
UPDATE public.user_branches ub
SET roles = u.roles
FROM public.users u
WHERE ub.user_id = u.id
  AND cardinality(ub.roles) = 0
  AND cardinality(u.roles) > 0;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS global_roles "UserRole"[] NOT NULL DEFAULT '{}';

-- Owner / manajer pusat (tanpa cabang di junction) → global_roles
UPDATE public.users u
SET global_roles = u.roles
WHERE cardinality(u.global_roles) = 0
  AND (
    'OWNER' = ANY (u.roles)
    OR (
      'MANAGER' = ANY (u.roles)
      AND NOT EXISTS (
        SELECT 1 FROM public.user_branches ub WHERE ub.user_id = u.id
      )
    )
  );
