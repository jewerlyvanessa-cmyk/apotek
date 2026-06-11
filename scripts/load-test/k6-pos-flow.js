/**
 * Load test alur POS: order → pembayaran tunai.
 *
 * Prasyarat: API + DB seed (`npm run db:seed` di folder api).
 *
 *   k6 run scripts/load-test/k6-pos-flow.js
 *   k6 run -e BASE_URL=http://localhost:3000/api/v1 scripts/load-test/k6-pos-flow.js
 */
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000/api/v1';

export const options = {
  scenarios: {
    pos_flow: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 10 },
        { duration: '1m', target: 10 },
        { duration: '15s', target: 0 },
      ],
      gracefulRampDown: '10s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.05'],
    http_req_duration: ['p(95)<3000'],
    checks: ['rate>0.9'],
  },
};

function login(email) {
  const res = http.post(
    `${BASE_URL}/auth/login`,
    JSON.stringify({
      email,
      password: 'password123',
      device_name: 'k6',
    }),
    { headers: { 'Content-Type': 'application/json' }, tags: { name: 'login' } },
  );
  check(res, { 'login ok': (r) => r.status === 201 });
  if (res.status !== 201) return null;
  return res.json('data.access_token');
}

function authHeaders(token) {
  return {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
}

function findMedicineId(staffToken) {
  const res = http.get(`${BASE_URL}/medicines?search=Paracetamol&limit=1`, {
    headers: authHeaders(staffToken),
    tags: { name: 'medicines' },
  });
  check(res, { 'medicines ok': (r) => r.status === 200 });
  const items = res.json('data.items');
  if (!items || items.length === 0) return null;
  return items[0].id;
}

export default function () {
  const health = http.get(`${BASE_URL}/health`, { tags: { name: 'health' } });
  check(health, {
    'health reachable': (r) => r.status === 200 || r.status === 503,
  });

  const staffToken = login('pelayan@apotikflow.com');
  if (!staffToken) {
    sleep(1);
    return;
  }

  const medicineId = findMedicineId(staffToken);
  if (!medicineId) {
    sleep(1);
    return;
  }

  const orderRes = http.post(
    `${BASE_URL}/orders`,
    JSON.stringify({
      customer_name: `k6-${__VU}-${Date.now()}`,
      items: [{ medicine_id: medicineId, quantity: 1 }],
    }),
    { headers: authHeaders(staffToken), tags: { name: 'create_order' } },
  );
  const orderOk = check(orderRes, {
    'order created': (r) => r.status === 201,
  });
  if (!orderOk) {
    sleep(1);
    return;
  }

  const orderId = orderRes.json('data.id');
  const total = Number(orderRes.json('data.total'));

  const cashierToken = login('kasir@apotikflow.com');
  if (!cashierToken) {
    sleep(1);
    return;
  }

  const payRes = http.post(
    `${BASE_URL}/payments`,
    JSON.stringify({
      order_id: orderId,
      payment_method: 'CASH',
      amount: total,
      amount_received: total + 50000,
    }),
    { headers: authHeaders(cashierToken), tags: { name: 'pay_order' } },
  );
  check(payRes, {
    'payment ok': (r) => r.status === 201,
    'order paid': (r) => r.json('data.status') === 'PAID',
  });

  sleep(0.5 + Math.random() * 0.5);
}
