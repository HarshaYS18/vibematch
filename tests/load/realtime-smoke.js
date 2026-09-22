import ws from 'k6/ws';
import { check } from 'k6';

const gateway = __ENV.FUNKEY_WS_URL || 'ws://host.docker.internal:8081/ws';
const token = __ENV.FUNKEY_TEST_TOKEN;

export const options = {
  vus: Number(__ENV.VUS || 5),
  duration: __ENV.DURATION || '30s',
};

export default function () {
  if (!token) throw new Error('FUNKEY_TEST_TOKEN is required for realtime load tests');
  const response = ws.connect(gateway, { headers: { Authorization: `Bearer ${token}` } }, (socket) => {
    socket.setTimeout(() => socket.close(), 5000);
    socket.on('error', (error) => console.error(error));
  });
  check(response, { 'WebSocket upgraded': (r) => r && r.status === 101 });
}
