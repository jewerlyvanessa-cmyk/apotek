#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SQL_FILE="$ROOT/prisma/sql/tenant-db-permissions.sql"

DB_NAME="${PGDATABASE:-apotikflow}"
PG_USER="${PGUSER:-postgres}"
PG_HOST="${PGHOST:-127.0.0.1}"
PG_PORT="${PGPORT:-5432}"

echo "Applying tenant DB permissions to database: $DB_NAME"
echo "Using PostgreSQL user: $PG_USER @ $PG_HOST:$PG_PORT"
echo ""

psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$DB_NAME" -f "$SQL_FILE"

echo ""
echo "Done. Update api/.env:"
echo '  DATABASE_URL="postgresql://apotikflow_app:apotikflow_app_secret@127.0.0.1:5432/apotikflow?schema=public"'
echo '  PLATFORM_DATABASE_URL="postgresql://apotikflow_platform:apotikflow_platform_secret@127.0.0.1:5432/apotikflow?schema=public"'
echo ""
echo "Keep your existing user (e.g. apotikflow) for: npx prisma db push / migrate"
