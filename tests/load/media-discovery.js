import http from 'k6/http';
import { check, sleep } from 'k6';

const base = __ENV.FUNKEY_API_URL || 'http://host.docker.internal:8000';
const token = __ENV.FUNKEY_TEST_TOKEN;
const room = __ENV.FUNKEY_TEST_ROOM_ID;

export const options = { vus: Number(__ENV.VUS || 5), duration: __ENV.DURATION || '30s' };

export default function () {
  if (!token || !room) throw new Error('FUNKEY_TEST_TOKEN and FUNKEY_TEST_ROOM_ID are required');
  const response = http.get(`${base}/api/v1/rooms/${encodeURIComponent(room)}/media`, {
    headers: { Authorization: `Bearer ${token}` },
    timeout: '5s',
  });
  check(response, {
    'media discovery authorized': (r) => r.status === 200,
    'backend assigned signaling URL': (r) => r.status === 200 && !!r.json('signaling_url'),
  });
  sleep(1);
}
