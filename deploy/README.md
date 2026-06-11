# Deploy assets — ApotikFlow

File pendukung instalasi **beli putus / on-prem**.

| Path | Fungsi |
|------|--------|
| `backend/` | Bundle API hasil `npm run deploy:prepare` (auto-generate) |
| `systemd/apotikflow-api.service` | Unit systemd — auto-start & restart API |
| `nginx/apotikflow.conf.example` | Reverse proxy API + host Flutter web |

## Siapkan paket rilis (vendor)

```bash
chmod +x scripts/build-release.sh
./scripts/build-release.sh
```

Output di folder `release/`:
- `apotikflow-backend.zip`
- `apotikflow-web.zip` (jika Flutter terpasang)
- `README-RILIS.txt`

## Instalasi systemd (Linux)

```bash
sudo useradd -r -s /bin/false apotikflow || true
sudo mkdir -p /opt/apotikflow-backend
sudo cp -r deploy/backend/* /opt/apotikflow-backend/
sudo chown -R apotikflow:apotikflow /opt/apotikflow-backend

sudo cp deploy/systemd/apotikflow-api.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable apotikflow-api
sudo systemctl start apotikflow-api
sudo systemctl status apotikflow-api
```

Restart setelah wizard database:

```bash
sudo systemctl restart apotikflow-api
```

## Docker production

```bash
cp api/.env.example api/.env   # edit secrets
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml exec api npx prisma migrate deploy
```

Panduan lengkap:

- **Beli putus (on-prem):** `referensi/14. runbook on-prem pelanggan pertama.md` (ringkas) · `referensi/10. checklist beli putus.md` (detail)
- **SaaS satu VPS:** `referensi/13. runbook saas satu vps.md`
- **Demo online (sales):** `referensi/15. runbook demo online calon pelanggan.md`
