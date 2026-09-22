import ws from 'k6/ws';
import { check, sleep } from 'k6';

const gateway = __ENV.FUNKEY_WS_URL || 'ws://host.docker.internal:8081/ws';
const token = __ENV.FUNKEY_TEST_TOKEN;
const room = __ENV.FUNKEY_TEST_ROOM_ID || '';
const holdMs = Number(__ENV.HOLD_MS || 1000);

export const options = {
  vus: Number(__ENV.VUS || 20),
  duration: __ENV.DURATION || '2m',
  thresholds: {
    checks: ['rate>0.99'],
  },
};

export default function () {
  if (!token) throw new Error('FUNKEY_TEST_TOKEN is required for reconnect tests');
  const response = ws.connect(
    gateway,
    { headers: { Authorization: `Bearer ${token}` } },
    (socket) => {
      socket.on('open', () => {
        if (room) socket.send(JSON.stringify({ type: 'subscribe', room_public_id: room }));
        socket.setTimeout(() => socket.close(), holdMs);
      });
      socket.on('error', (error) => console.error(error));
    },
  );
  check(response, { 'reconnect upgraded': (result) => result && result.status === 101 });
  sleep(Math.random() * 0.5);
}
