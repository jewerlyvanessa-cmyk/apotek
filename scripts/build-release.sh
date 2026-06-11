#!/usr/bin/env bash
# Siapkan paket rilis beli putus untuk dikirim ke pelanggan.
# Usage: ./scripts/build-release.sh [--skip-flutter]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/release"
SKIP_FLUTTER=false

for arg in "$@"; do
  case "$arg" in
    --skip-flutter) SKIP_FLUTTER=true ;;
    -h|--help)
      echo "Usage: $0 [--skip-flutter]"
      exit 0
      ;;
  esac
done

echo "==> ApotikFlow release build"
echo "    Root: $ROOT"

# 1) Backend bundle
echo "==> [1/3] Backend (npm run deploy:prepare)"
cd "$ROOT/api"
npm run deploy:prepare

# 2) Deploy extras (systemd, nginx)
echo "==> [2/3] Salin file deploy (systemd, nginx)"
mkdir -p "$OUT/apotikflow-backend"
rsync -a --delete "$ROOT/deploy/backend/" "$OUT/apotikflow-backend/"
mkdir -p "$OUT/deploy-extras"
cp "$ROOT/deploy/systemd/apotikflow-api.service" "$OUT/deploy-extras/"
cp "$ROOT/deploy/nginx/apotikflow.conf.example" "$OUT/deploy-extras/"
cp "$ROOT/docker-compose.prod.yml" "$OUT/deploy-extras/"
cp "$ROOT/referensi/10. checklist beli putus.md" "$OUT/"

# Zip backend
cd "$OUT"
rm -f apotikflow-backend.zip
zip -rq apotikflow-backend.zip apotikflow-backend deploy-extras

# 3) Flutter (opsional)
if [ "$SKIP_FLUTTER" = false ]; then
  if command -v flutter >/dev/null 2>&1; then
    echo "==> [3/3] Flutter web release"
    cd "$ROOT/app"
    flutter pub get
    flutter build web --release -t lib/main_production.dart
    rm -rf "$OUT/apotikflow-web"
    cp -R build/web "$OUT/apotikflow-web"
    cd "$OUT"
    rm -f apotikflow-web.zip
    zip -rq apotikflow-web.zip apotikflow-web
    echo "    Web build: $OUT/apotikflow-web.zip"
  else
    echo "==> [3/3] Flutter tidak terpasang — lewati (gunakan --skip-flutter untuk menekan peringatan)"
  fi
else
  echo "==> [3/3] Flutter dilewati (--skip-flutter)"
fi

cat > "$OUT/README-RILIS.txt" <<'EOF'
Paket rilis ApotikFlow (beli putus)
===================================

Isi folder release/:
  apotikflow-backend.zip   — Backend API + prisma + deploy-extras
  apotikflow-web.zip       — Flutter web (jika build berhasil)
  10. checklist beli putus.md — Panduan instalasi lengkap

Langkah singkat server:
  1. unzip apotikflow-backend.zip
  2. cd apotikflow-backend && cp .env.example .env (edit)
  3. npm ci --omit=dev && npx prisma migrate deploy
  4. sudo cp ../deploy-extras/apotikflow-api.service /etc/systemd/system/
  5. sudo systemctl enable --now apotikflow-api

Flutter web (opsional):
  unzip apotikflow-web.zip ke /var/www/apotikflow-web
  sudo cp deploy-extras/apotikflow.conf.example /etc/nginx/sites-available/apotikflow

Detail: lihat "10. checklist beli putus.md"
EOF

echo ""
echo "Selesai. Output: $OUT"
ls -lh "$OUT"/*.zip 2>/dev/null || true
echo "Baca: $OUT/README-RILIS.txt"
