import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const base = __ENV.FUNKEY_API_URL || 'http://host.docker.internal:8000';
const token = __ENV.FUNKEY_TEST_TOKEN || '';

const PersistedGraphqlOperations = {
  homeComposite:
    '49caa7816c5a823071f7b812cfcc35b6ee996fe337da55dce98f121c776c16f6',
};

const unexpectedFailureRate = new Rate('graphql_unexpected_failure_rate');
const semanticErrorRate = new Rate('graphql_semantic_error_rate');
const homeCompositeDuration = new Trend('graphql_home_composite_duration', true);
const bffServerDuration = new Trend('graphql_bff_server_duration', true);

export const options = {
  vus: Number(__ENV.VUS || 5),
  duration: __ENV.DURATION || '30s',
  summaryTrendStats: ['avg', 'med', 'p(95)', 'p(99)', 'max'],
  thresholds: {
    http_req_failed: ['rate==0'],
    checks: ['rate==1'],
    graphql_unexpected_failure_rate: ['rate==0'],
    graphql_semantic_error_rate: ['rate==0'],
    graphql_home_composite_duration: ['p(95)<250', 'p(99)<500'],
    graphql_bff_server_duration: ['p(95)<200', 'p(99)<400'],
  },
};

export function setup() {
  if (!token) {
    throw new Error(
      'FUNKEY_TEST_TOKEN is required; authenticated GraphQL smoke must never pass by doing no work.',
    );
  }
  return {};
}

function decodeGraphqlResponse(response) {
  try {
    return response.json();
  } catch (_) {
    return null;
  }
}

function parseBffServerTiming(response) {
  const value = response.headers['Server-Timing'] || response.headers['server-timing'];
  if (!value) {
    return null;
  }
  const match = /(?:^|,\s*)bff;dur=([0-9]+(?:\.[0-9]+)?)/.exec(value);
  return match ? Number(match[1]) : null;
}

function hasCompleteHomeComposite(body) {
  const home = body && body.data && body.data.home;
  if (!home || typeof home !== 'object') {
    return false;
  }
  return ['myRoom', 'eventBanners', 'policyBanners'].every((field) =>
    Object.prototype.hasOwnProperty.call(home, field),
  );
}

export default function () {
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
      tags: {
        operation: 'HomeComposite',
        workload: 'graphql-persisted-smoke',
      },
      timeout: '3s',
    },
  );

  homeCompositeDuration.add(response.timings.duration, {
    operation: 'HomeComposite',
  });

  const body = decodeGraphqlResponse(response);
  const bffDurationMs = parseBffServerTiming(response);
  if (bffDurationMs !== null) {
    bffServerDuration.add(bffDurationMs, { operation: 'HomeComposite' });
  }

  const transportAccepted = response.status === 200;
  const semanticErrors =
    body && Array.isArray(body.errors) ? body.errors.length : body ? 0 : 1;
  const completeHome = hasCompleteHomeComposite(body);
  const serverTimingPresent = bffDurationMs !== null;
  const semanticFailure = !body || semanticErrors > 0 || !completeHome;
  const unexpectedFailure =
    !transportAccepted || semanticFailure || !serverTimingPresent;

  semanticErrorRate.add(semanticFailure, { operation: 'HomeComposite' });
  unexpectedFailureRate.add(unexpectedFailure, { operation: 'HomeComposite' });

  check(
    response,
    {
      'GraphQL persisted read accepted': () => transportAccepted,
      'GraphQL response is valid JSON': () => body !== null,
      'GraphQL response has zero semantic errors': () => semanticErrors === 0,
      'Home composite returned every required field': () => completeHome,
      'BFF Server-Timing is present': () => serverTimingPresent,
    },
    { operation: 'HomeComposite' },
  );

  sleep(1);
}
