# Load test ApotikFlow (k6)

Prasyarat: [k6](https://k6.io/) terpasang, API jalan, DB di-seed (`cd api && npm run db:seed`).

| Skrip | Tujuan |
|-------|--------|
| `k6-smoke.js` | Health + login + dashboard (5 VU, 30s) |
| `k6-pos-flow.js` | Alur order → bayar tunai (10 VU, ~2 menit) |
| `k6-10k-daily.js` | Simulasi ~10.000 trx/hari (~7 trx/menit) |

```bash
# Smoke
k6 run scripts/load-test/k6-smoke.js

# Alur POS
k6 run -e BASE_URL=http://localhost:3000/api/v1 scripts/load-test/k6-pos-flow.js

# Beban harian (default 10 menit)
k6 run scripts/load-test/k6-10k-daily.js

# Beban 5 menit, target 10rb/hari
k6 run -e DURATION=5m -e DAILY_TARGET=10000 scripts/load-test/k6-10k-daily.js
```

Threshold gagal → periksa log API, koneksi DB, dan stok seed (Paracetamol).
