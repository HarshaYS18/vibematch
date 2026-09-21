import assert from 'node:assert/strict';
import http from 'node:http';
import { once } from 'node:events';
import { test } from 'node:test';
import { config } from '../src/config.js';
import { HeartbeatLoop } from '../src/control/heartbeatLoop.js';
import { heartbeatMediaNode, registryIsHealthy, RegistryRequestError } from '../src/control/registryClient.js';

const stats = { roomCount: 0, peerCount: 0, roomIds: [] };

async function withRegistry(handler: http.RequestListener, run: () => Promise<void>): Promise<void> {
  const server = http.createServer(handler);
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const address = server.address();
  assert.ok(address && typeof address !== 'string');
  const previousBaseUrl = config.fastApiBaseUrl;
  config.fastApiBaseUrl = `http://127.0.0.1:${address.port}`;
  try { await run(); } finally {
    config.fastApiBaseUrl = previousBaseUrl;
    await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}

test('registry heartbeat consumes successful responses and sends a request ID', async () => {
  let requestId: string | undefined;
  await withRegistry((request, response) => {
    requestId = request.headers['x-request-id'];
    request.resume();
    response.writeHead(200, { 'Content-Type': 'application/json' });
    response.write('{"ok":');
    setImmediate(() => response.end('true}'));
  }, async () => heartbeatMediaNode(stats));
  assert.match(requestId ?? '', /^[0-9a-f-]{36}$/);
});

test('failed registry request does not prevent the next heartbeat from recovering', async () => {
  let calls = 0;
  await withRegistry((request, response) => {
    request.resume();
    calls++;
    response.statusCode = calls === 1 ? 503 : 200;
    response.end(calls === 1 ? 'unavailable' : '{"ok":true}');
  }, async () => {
    await assert.rejects(heartbeatMediaNode(stats), RegistryRequestError);
    assert.equal(registryIsHealthy(), false);
    await heartbeatMediaNode(stats);
    assert.equal(registryIsHealthy(), true);
  });
  assert.equal(calls, 2);
});

test('registry heartbeat fails within its configured bound when a response stalls', async () => {
  const previousTimeout = config.verifyTimeoutMs;
  config.verifyTimeoutMs = 50;
  try {
    await withRegistry((request) => { request.resume(); }, async () => {
      const startedAt = performance.now();
      await assert.rejects(heartbeatMediaNode(stats), RegistryRequestError);
      assert.ok(performance.now() - startedAt < 500);
    });
  } finally { config.verifyTimeoutMs = previousTimeout; }
});

test('heartbeat loop coalesces concurrent timer triggers', async () => {
  let calls = 0;
  let release: (() => void) | undefined;
  const pending = new Promise<void>((resolve) => { release = resolve; });
  const loop = new HeartbeatLoop(1000, async () => { calls++; await pending; });
  const first = loop.trigger();
  const second = loop.trigger();
  assert.equal(calls, 1);
  release?.();
  await Promise.all([first, second]);
});
