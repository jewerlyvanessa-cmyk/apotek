/**
 * Simulasi beban ~10.000 transaksi/hari (alur POS lengkap).
 *
 * 10.000 / 24 jam ≈ 7 transaksi/menit → constant-arrival-rate 7/m.
 *
 * Prasyarat: API + seed (`cd api && npm run db:seed`).
 *
 *   k6 run scripts/load-test/k6-10k-daily.js
 *   k6 run -e BASE_URL=http://localhost:3000/api/v1 -e DURATION=5m scripts/load-test/k6-10k-daily.js
 */
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000/api/v1';
const DURATION = __ENV.DURATION || '10m';
/** Target transaksi per hari (default 10.000). */
const DAILY_TARGET = Number(__ENV.DAILY_TARGET || 10000);
/** ~7 trx/menit pada 10rb/hari */
const RATE_PER_MINUTE = Math.max(1, Math.ceil(DAILY_TARGET / 24 / 60));

export const options = {
  scenarios: {
    daily_pace: {
      executor: 'constant-arrival-rate',
      rate: RATE_PER_MINUTE,
      timeUnit: '1m',
      duration: DURATION,
      preAllocatedVUs: 15,
      maxVUs: 40,
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.08'],
    http_req_duration: ['p(95)<5000'],
    checks: ['rate>0.85'],
  },
};

function login(email) {
  const res = http.post(
    `${BASE_URL}/auth/login`,
    JSON.stringify({
      email,
      password: 'password123',
      device_name: 'k6-10k',
    }),
    { headers: { 'Content-Type': 'application/json' }, tags: { name: 'login' } },
  );
  if (res.status !== 201) return null;
  return res.json('data.access_token');
}

function authHeaders(token) {
  return {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
}

let cachedMedicineId = null;

function medicineId(staffToken) {
  if (cachedMedicineId) return cachedMedicineId;
  const res = http.get(`${BASE_URL}/medicines?search=Paracetamol&limit=1`, {
    headers: authHeaders(staffToken),
    tags: { name: 'medicines' },
  });
  if (res.status !== 200) return null;
  const items = res.json('data.items');
  if (!items || items.length === 0) return null;
  cachedMedicineId = items[0].id;
  return cachedMedicineId;
}

export function setup() {
  const health = http.get(`${BASE_URL}/health`);
  check(health, { 'health ok': (r) => r.status === 200 || r.status === 503 });
  return { ratePerMinute: RATE_PER_MINUTE, dailyTarget: DAILY_TARGET };
}

export default function () {
  const staffToken = login('pelayan@apotikflow.com');
  if (!staffToken) return;

  const medId = medicineId(staffToken);
  if (!medId) return;

  const orderRes = http.post(
    `${BASE_URL}/orders`,
    JSON.stringify({
      customer_name: `k10k-${__ITER}`,
      items: [{ medicine_id: medId, quantity: 1 }],
    }),
    { headers: authHeaders(staffToken), tags: { name: 'create_order' } },
  );
  if (orderRes.status !== 201) return;

  const orderId = orderRes.json('data.id');
  const total = Number(orderRes.json('data.total'));

  const cashierToken = login('kasir@apotikflow.com');
  if (!cashierToken) return;

  const payRes = http.post(
    `${BASE_URL}/payments`,
    JSON.stringify({
      order_id: orderId,
      payment_method: 'CASH',
      amount: total,
      amount_received: total + 10000,
    }),
    { headers: authHeaders(cashierToken), tags: { name: 'pay_order' } },
  );

  check(payRes, {
    'payment 201': (r) => r.status === 201,
    'status PAID': (r) => r.json('data.status') === 'PAID',
  });

  sleep(0.1);
}

export function handleSummary(data) {
  const iterations = data.metrics.iterations?.values?.count ?? 0;
  const projectedDaily = Math.round((iterations / (data.state.testRunDurationMs / 1000)) * 86400);
  return {
    stdout: [
      '',
      '--- Ringkasan beban harian ---',
      `Target: ${DAILY_TARGET} trx/hari (~${RATE_PER_MINUTE} trx/menit)`,
      `Iterasi selesai: ${iterations}`,
      `Proyeksi 24 jam (dari durasi tes): ~${projectedDaily} trx/hari`,
      '',
    ].join('\n'),
  };
}
