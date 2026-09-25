import http from 'k6/http';
import { check, sleep } from 'k6';

const base = __ENV.FUNKEY_API_URL || 'http://host.docker.internal:8000';
const token = __ENV.FUNKEY_TEST_TOKEN || '';

const PersistedGraphqlOperations = {
  homeComposite:
    '49caa7816c5a823071f7b812cfcc35b6ee996fe337da55dce98f121c776c16f6',
};

export const options = {
  vus: Number(__ENV.VUS || 5),
  duration: __ENV.DURATION || '30s',
  thresholds: {
    http_req_failed: ['rate<0.02'],
    http_req_duration: ['p(95)<1500'],
  },
};

export default function () {
  if (!token) {
    sleep(1);
    return;
  }

  const response = http.post(
    `${base}/graphql`,
    JSON.stringify({
      id: PersistedGraphqlOperations.homeComposite,
      variables: {},
    }),
    {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      timeout: '10s',
    },
  );

  check(response, {
    'GraphQL persisted read accepted': (r) => r.status === 200,
    'Home composite returned data': (r) => {
      try {
        const body = r.json();
        return body && body.data && body.data.home;
      } catch (_) {
        return false;
      }
    },
  });
  sleep(1);
}
