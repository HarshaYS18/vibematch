import http from 'k6/http';
import { check, sleep } from 'k6';

const base = __ENV.FUNKEY_API_URL || 'http://host.docker.internal:8000';
const token = __ENV.FUNKEY_TEST_TOKEN || '';

export const options = {
  vus: Number(__ENV.VUS || 5),
  duration: __ENV.DURATION || '30s',
  thresholds: {
    http_req_failed: ['rate<0.05'],
    http_req_duration: ['p(95)<1000'],
  },
};

export default function () {
  const live = http.get(`${base}/live`, { timeout: '5s' });
  check(live, { 'API live': (r) => r.status === 200 });

  const ready = http.get(`${base}/ready`, { timeout: '5s' });
  check(ready, { 'API ready': (r) => r.status === 200 });

  if (token) {
    const user = http.get(`${base}/api/v1/users/me`, {
      headers: { Authorization: `Bearer ${token}` },
      timeout: '5s',
    });
    check(user, { 'authenticated snapshot': (r) => r.status === 200 });
  }
  sleep(1);
}
