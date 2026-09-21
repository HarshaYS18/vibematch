import assert from 'node:assert/strict';
import { test } from 'node:test';
import { verifyMediaAction } from '../src/auth/fastapiVerifier.js';

test('control-plane failure and denied permissions fail closed', async () => {
  const original = globalThis.fetch;
  try {
    for (const status of [403, 409, 503]) {
      globalThis.fetch = async () => new Response('denied', { status });
      await assert.rejects(verifyMediaAction({ bearerToken: 'test', requestedAction: 'produce_audio' }));
    }
    globalThis.fetch = async () => new Response(JSON.stringify({ allowed: false, reason: 'no seat' }));
    await assert.rejects(verifyMediaAction({ bearerToken: 'test', requestedAction: 'resume_producer' }), /no seat/);
  } finally { globalThis.fetch = original; }
});
