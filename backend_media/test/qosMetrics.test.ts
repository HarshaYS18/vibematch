import assert from 'node:assert/strict';
import test from 'node:test';

import { joinMetrics, recordJoin } from '../src/signaling/metrics.js';

test('join latency histogram is cumulative and bounded', () => {
  const before = joinMetrics();
  recordJoin(true, 90);
  recordJoin(false, 900);
  const after = joinMetrics();
  assert.equal(after.succeeded, before.succeeded + 1);
  assert.equal(after.failed, before.failed + 1);
  assert.equal(after.durationObservations, before.durationObservations + 2);
  const oneSecond = after.durationBucketsMs.indexOf(1000);
  assert.ok(oneSecond >= 0);
  assert.equal(after.durationCounts[oneSecond], before.durationCounts[oneSecond] + 2);
});
