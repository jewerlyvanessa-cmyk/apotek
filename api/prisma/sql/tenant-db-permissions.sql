-- =============================================================================
-- Pembatasan akses tabel `tenants` di PostgreSQL
-- Jalankan sebagai superuser (postgres):
--   psql -U postgres -d apotikflow -f prisma/sql/tenant-db-permissions.sql
--
-- Setelah ini, ubah api/.env:
--   DATABASE_URL          -> apotikflow_app   (API umum, tidak bisa ubah tenants)
--   PLATFORM_DATABASE_URL -> apotikflow_platform (modul /platform Super Admin)
--   prisma migrate        -> user owner/migrate (mis. apotikflow atau postgres)
-- =============================================================================

-- Password dev di bawah — GANTI di production

-- Role aplikasi (API sehari-hari)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'apotikflow_app') THEN
    CREATE ROLE apotikflow_app WITH LOGIN PASSWORD 'apotikflow_app_secret';
  ELSE
    ALTER ROLE apotikflow_app WITH LOGIN PASSWORD 'apotikflow_app_secret';
  END IF;
END
$$;

-- Role platform (Super Admin — boleh ubah tenants)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'apotikflow_platform') THEN
    CREATE ROLE apotikflow_platform WITH LOGIN PASSWORD 'apotikflow_platform_secret';
  ELSE
    ALTER ROLE apotikflow_platform WITH LOGIN PASSWORD 'apotikflow_platform_secret';
  END IF;
END
$$;

-- Izin schema
GRANT USAGE ON SCHEMA public TO apotikflow_app;
GRANT USAGE ON SCHEMA public TO apotikflow_platform;

-- Owner tabel tenants ke postgres agar role lama tidak bypass
ALTER TABLE IF EXISTS public.tenants OWNER TO postgres;

REVOKE ALL ON TABLE public.tenants FROM PUBLIC;

-- API: baca tenant + sinkron langganan dari lisensi on-prem
REVOKE ALL ON TABLE public.tenants FROM apotikflow_app;
GRANT SELECT (
  id, name, code, is_active, subscription_plan, subscription_expired_at
) ON public.tenants TO apotikflow_app;
GRANT UPDATE (
  subscription_plan, subscription_expired_at, is_active
) ON public.tenants TO apotikflow_app;

-- Platform: kelola tenant penuh
REVOKE ALL ON TABLE public.tenants FROM apotikflow_platform;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.tenants TO apotikflow_platform;

-- Tabel bisnis lain: CRUD untuk app + platform
DO $$
DECLARE
  tbl RECORD;
BEGIN
  FOR tbl IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename <> 'tenants'
  LOOP
    EXECUTE format(
      'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.%I TO apotikflow_app',
      tbl.tablename
    );
    EXECUTE format(
      'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.%I TO apotikflow_platform',
      tbl.tablename
    );
  END LOOP;
END
$$;

-- Sequence (serial/uuid default)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO apotikflow_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO apotikflow_platform;

-- Default privilege untuk tabel baru dari migrasi Prisma
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO apotikflow_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO apotikflow_platform;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO apotikflow_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO apotikflow_platform;
