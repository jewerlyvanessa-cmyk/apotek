#!/usr/bin/env node
/**
 * Mock HTTP QRIS provider untuk uji integrasi lokal (prd-5).
 *
 *   node scripts/qris-mock-provider.mjs
 *   QRIS_PROVIDER=http QRIS_API_URL=http://127.0.0.1:3999/v1/charges npm run start:dev
 *
 * Webhook uji (setelah order QRIS):
 *   curl -X POST http://localhost:3000/api/v1/payments/qris/webhook \
 *     -H "Content-Type: application/json" \
 *     -H "x-webhook-secret: dev-qris-secret" \
 *     -d '{"reference_number":"QRIS-xxx","status":"PAID","amount":50000}'
 */
import http from 'node:http';

const PORT = Number(process.env.QRIS_MOCK_PORT || 3999);
const charges = new Map();

const server = http.createServer(async (req, res) => {
  if (req.method === 'POST' && req.url === '/v1/charges') {
    let body = '';
    for await (const chunk of req) body += chunk;
    let payload;
    try {
      payload = JSON.parse(body || '{}');
    } catch {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ message: 'Invalid JSON' }));
      return;
    }

    const ref =
      payload.reference_number ||
      payload.reference ||
      `MOCK-${Date.now()}`;
    const amount = Number(payload.amount || 0);
    const qr_string = `qris://mock-provider/${ref}?amount=${amount}`;
    charges.set(ref, { amount, qr_string });

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(
      JSON.stringify({
        reference_number: ref,
        qr_string,
        status: 'PENDING',
      }),
    );
    console.log(`[charge] ${ref} amount=${amount}`);
    return;
  }

  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, charges: charges.size }));
    return;
  }

  res.writeHead(404);
  res.end();
});

server.listen(PORT, () => {
  console.log(`QRIS mock provider → http://127.0.0.1:${PORT}/v1/charges`);
});
