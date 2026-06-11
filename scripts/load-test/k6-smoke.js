/**
 * Smoke / light load test ApotikFlow API.
 *
 * Prasyarat: API jalan, DB + seed (`npm run db:seed` di folder api).
 *
 *   k6 run scripts/load-test/k6-smoke.js
 *   k6 run -e BASE_URL=http://localhost:3000/api/v1 scripts/load-test/k6-smoke.js
 *
 * Alur POS: scripts/load-test/k6-pos-flow.js
 * Beban 10rb/hari: scripts/load-test/k6-10k-daily.js
 */
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000/api/v1';

export const options = {
  vus: 5,
  duration: '30s',
  thresholds: {
    http_req_failed: ['rate<0.05'],
    http_req_duration: ['p(95)<2000'],
  },
};

export default function () {
  const health = http.get(`${BASE_URL}/health`);
  check(health, {
    'health status 200 or 503': (r) => r.status === 200 || r.status === 503,
    'health has body': (r) => r.body && r.body.length > 0,
  });

  const login = http.post(
    `${BASE_URL}/auth/login`,
    JSON.stringify({
      email: 'owner@apotikflow.com',
      password: 'password123',
      device_name: 'k6',
    }),
    { headers: { 'Content-Type': 'application/json' } },
  );

  const loggedIn = check(login, {
    'login 201': (r) => r.status === 201,
  });

  if (loggedIn) {
    const token = login.json('data.access_token');
    const headers = {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    };

    const dashboard = http.get(`${BASE_URL}/reports/dashboard`, { headers });
    check(dashboard, {
      'dashboard 200': (r) => r.status === 200,
    });
  }

  sleep(1);
}
