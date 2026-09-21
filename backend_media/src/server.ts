import http from 'node:http';
import cors from 'cors';
import express from 'express';
import { config } from './config.js';
import { markMediaNodeOffline, heartbeatMediaNode, registryIsHealthy } from './control/registryClient.js';
import { WorkerManager } from './mediasoup/workerManager.js';
import { RoomManager } from './mediasoup/roomManager.js';
import { createSocketServer } from './signaling/socketServer.js';

const app = express();
app.use(cors({ origin: config.corsOrigin, credentials: true }));
app.use(express.json({ limit: '256kb' }));

const workerManager = new WorkerManager();
await workerManager.start();
const roomManager = new RoomManager(workerManager);

app.get('/health', (_request, response) => {
  response.json({
    status: 'healthy',
    service: 'funkey-media-worker',
    nodeId: config.registry.nodeId,
    fastApiBaseUrl: config.fastApiBaseUrl,
    ...roomManager.getStats(),
  });
});

app.get('/ready', (_request, response) => {
  const ready = workerManager.isReady && registryIsHealthy();
  response.status(ready ? 200 : 503).json({
    status: ready ? 'ready' : 'not_ready',
    nodeId: config.registry.nodeId,
    workerReady: workerManager.isReady,
    registryHealthy: registryIsHealthy(),
    ...roomManager.getStats(),
  });
});

app.get('/', (_request, response) => {
  response.json({
    service: 'funkey-media-worker',
    status: 'ok',
    nodeId: config.registry.nodeId,
    signaling: 'socket.io',
    sourceOfTruth: 'FastAPI /api/v1/media-realtime/verify',
  });
});

const httpServer = http.createServer(app);
const io = createSocketServer(httpServer, roomManager);

let heartbeatTimer: NodeJS.Timeout | undefined;

async function sendHeartbeat(): Promise<void> {
  try {
    await heartbeatMediaNode(roomManager.getStats());
  } catch (error) {
    console.error('[media] registry heartbeat failed', error);
  }
}

httpServer.listen(config.port, config.host, () => {
  console.log(`[media] node=${config.registry.nodeId} running on http://${config.host}:${config.port}`);
  console.log(`[media] public signaling url=${config.registry.publicUrl}`);
  console.log(
    `[media] mediasoup listenIp=${config.mediasoup.listenIp} announcedIp=${config.mediasoup.announcedIp} rtcPorts=${config.mediasoup.minPort}-${config.mediasoup.maxPort}`,
  );
  void sendHeartbeat();
  heartbeatTimer = setInterval(() => void sendHeartbeat(), config.registry.heartbeatIntervalMs);
});

let shuttingDown = false;
async function shutdown(signal: string) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`[media] received ${signal}; draining process.`);
  if (heartbeatTimer) clearInterval(heartbeatTimer);
  try {
    await markMediaNodeOffline();
  } catch (error) {
    console.error('[media] failed to unregister node cleanly', error);
  }
  io.close();
  workerManager.close();
  httpServer.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 5000).unref();
}

process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));
