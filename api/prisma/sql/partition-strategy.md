# Strategi Partition — Tabel Besar (roadmap)

**Status:** skrip migrasi awal tersedia (`scale-2`). Belum diaktifkan otomatis di Prisma — jalankan manual saat maintenance window.

## Kandidat tabel

| Tabel | Pertumbuhan | Skema partition disarankan |
|-------|-------------|----------------------------|
| `orders` | Tinggi (transaksi harian) | `RANGE (paid_at)` per bulan/kuartal |
| `stock_movements` | Sangat tinggi | `RANGE (created_at)` per bulan |
| `audit_logs` | Tinggi | `RANGE (created_at)` per bulan |

## Prasyarat PostgreSQL

1. Primary key harus mencakup kolom partition, mis. `(id, created_at)`.
2. Index query umum: `(tenant_id, branch_id, created_at DESC)`.
3. Retensi: arsip / drop partition > 24 bulan (sesuai kebijakan apotek).

## Langkah migrasi (ringkas)

1. Jalankan `api/prisma/sql/stock-movements-partition.sql` (parent + partisi awal + salin data).
2. Uncomment langkah swap nama di akhir skrip setelah verifikasi row count.
3. Job bulanan: `CREATE TABLE ... PARTITION OF` untuk periode berikutnya.
4. Ulangi pola yang sama untuk `orders` dan `audit_logs` setelah `stock_movements` stabil.

## Alternatif tanpa partition dulu

- Index partial: `WHERE status = 'PAID'` pada `orders`.
- Arsip cold storage: export order > 2 tahun ke object storage.
- Vacuum / analyze terjadwal.

Lihat juga `referensi/12. dokumentasi teknis operasional.md`.
