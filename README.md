# ApotikFlow

Aplikasi apotik multi-tenant — Flutter + NestJS + PostgreSQL.

## Struktur project

```
apotek/
├── api/          # Backend NestJS + Prisma
├── app/          # Frontend Flutter
├── referensi/    # Dokumentasi desain
└── docker-compose.yml   # opsional (tidak wajib untuk dev lokal)
```

## Quick start (tanpa Docker)

### 1. PostgreSQL lokal

Pasang PostgreSQL (mis. [Postgres.app](https://postgresapp.com/) atau `brew install postgresql@16`), lalu buat database:

```bash
createdb apotikflow
# atau lewat psql: CREATE DATABASE apotikflow;
```

Sesuaikan `DATABASE_URL` di `api/.env` (lihat `api/.env.example`).

### 2. Backend API

```bash
cd api
cp .env.example .env   # edit DATABASE_URL
npm install
npm run db:push
npm run db:seed
npm run start:dev
```

- API: http://localhost:3000/api/v1  
- Swagger: http://localhost:3000/docs  

**Redis / Docker tidak wajib.** Jika `REDIS_URL` tidak di-set, API memakai **cache in-memory** dan background job (BullMQ) nonaktif — cukup untuk development.

### 3. Flutter

```bash
cd app
flutter pub get
flutter run -d chrome   # atau emulator / device
```

**Akun pengembangan (setelah seed):**

Jalankan `npm run db:seed` di folder `api/`. Akun dan peran dibuat otomatis oleh skrip seed — lihat output terminal setelah seed selesai, atau daftar email di `api/prisma/seed.ts`. Jangan menaruh password di dokumentasi; untuk lingkungan non-dev, buat user lewat modul Platform/Admin, bukan seed.

### Uji coba MVP

1. Login owner → tab Stok (semua cabang) / Admin (user) / Reports  
2. Login kasir → Kasir → bayar order  
3. Login superadmin → Platform → kelola tenant & cabang  

---

## Opsional: Redis (tanpa Docker)

Hanya jika ingin cache Redis + antrian background job:

```bash
brew install redis
brew services start redis
```

Lalu di `api/.env`:

```env
REDIS_URL="redis://127.0.0.1:6379"
REDIS_PREFIX="apotikflow"
```

Restart API.

---

## Hak akses tabel `tenants` (PostgreSQL)

Agar hanya role tertentu yang bisa **mengubah** data tenant di database:

```bash
cd api
# Jalankan sebagai superuser postgres
npm run db:tenant-permissions
```

Lalu set di `api/.env`:

- `DATABASE_URL` → user `apotikflow_app` (API umum, baca tenant terbatas)
- `PLATFORM_DATABASE_URL` → user `apotikflow_platform` (modul `/platform` Super Admin)
- Prisma migrate → user owner DB, contoh:  
  `DATABASE_URL="postgresql://apotikflow:...@127.0.0.1:5432/apotikflow" npx prisma db push`

SQL: `api/prisma/sql/tenant-db-permissions.sql`

---

## Opsional: Docker Compose

Jika sudah memasang Docker Desktop:

```bash
docker compose up -d --build
docker compose exec api npm run db:migrate
docker compose exec api npm run db:seed
curl http://localhost:3000/api/v1/health
```

---

## Stack

| Layer | Teknologi |
|-------|-----------|
| Mobile/Web | Flutter, Riverpod, go_router |
| API | NestJS, Prisma, PostgreSQL |
| Cache | In-memory (default) atau Redis (opsional) |
| Realtime | Socket.IO |
