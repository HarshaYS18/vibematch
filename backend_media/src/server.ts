import http from 'node:http';
import cors from 'cors';
import express from 'express';
import { config } from './config.js';
import { markMediaNodeDraining, markMediaNodeOffline, heartbeatMediaNode, registryIsHealthy, RegistryRequestError } from './control/registryClient.js';
import { HeartbeatLoop } from './control/heartbeatLoop.js';
import { WorkerManager } from './mediasoup/workerManager.js';
import { RoomManager } from './mediasoup/roomManager.js';
import { createSocketServer } from './signaling/socketServer.js';
import { joinMetrics } from './signaling/metrics.js';

const app = express();
app.use(cors({ origin: config.corsOrigin, credentials: true }));
app.use(express.json({ limit: '256kb' }));

const workerManager = new WorkerManager();
await workerManager.start();
const roomManager = new RoomManager(workerManager);
let draining = false;
let shuttingDown = false;

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
  const ready = !draining && workerManager.isReady && registryIsHealthy();
  response.status(ready ? 200 : 503).json({
    status: ready ? 'ready' : 'not_ready',
    nodeId: config.registry.nodeId,
    workerReady: workerManager.isReady,
    registryHealthy: registryIsHealthy(),
    ...roomManager.getStats(),
  });
});

app.get('/metrics', (_request, response) => {
  const stats = roomManager.getStats();
  const joins = joinMetrics();
  response.type('text/plain; version=0.0.4').send([
    '# TYPE funkey_media_rooms gauge',
    `funkey_media_rooms ${stats.roomCount}`,
    '# TYPE funkey_media_peers gauge',
    `funkey_media_peers ${stats.peerCount}`,
    '# TYPE funkey_media_max_rooms gauge',
    `funkey_media_max_rooms ${config.registry.maxRooms}`,
    '# TYPE funkey_media_max_peers gauge',
    `funkey_media_max_peers ${config.registry.maxPeers}`,
    '# TYPE funkey_media_draining gauge',
    `funkey_media_draining ${draining ? 1 : 0}`,
    '# TYPE funkey_media_registry_healthy gauge',
    `funkey_media_registry_healthy ${registryIsHealthy() ? 1 : 0}`,
    '# TYPE funkey_media_joins_total counter',
    `funkey_media_joins_total{result="success"} ${joins.succeeded}`,
    `funkey_media_joins_total{result="failure"} ${joins.failed}`,
    '',
  ].join('\n'));
});

// The Kubernetes preStop hook uses loopback only. The shared media token never
// needs to be exposed in a pod lifecycle command or process argument.
app.post('/drain', async (request, response) => {
  const remote = request.socket.remoteAddress ?? '';
  if (!['127.0.0.1', '::1', '::ffff:127.0.0.1'].includes(remote)) {
    response.status(403).json({ error: 'loopback only' });
    return;
  }
  draining = true;
  try {
    await markMediaNodeDraining();
    response.json({ draining: true, ...roomManager.getStats() });
  } catch (error) {
    response.status(503).json({ error: 'registry drain unavailable' });
  }
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
const io = createSocketServer(httpServer, roomManager, () => draining);

async function sendHeartbeat(): Promise<void> {
  if (!workerManager.isReady) return;
  try {
    await heartbeatMediaNode(roomManager.getStats());
  } catch (error) {
    if (error instanceof RegistryRequestError) {
      console.error('[media] registry heartbeat failed', {
        requestId: error.requestId,
        elapsedMs: error.elapsedMs,
        phase: error.phase,
        error: error.message,
      });
    } else {
      console.error('[media] registry heartbeat failed', error);
    }
  }
}

const heartbeatLoop = new HeartbeatLoop(config.registry.heartbeatIntervalMs, sendHeartbeat);

httpServer.listen(config.port, config.host, () => {
  console.log(`[media] node=${config.registry.nodeId} running on http://${config.host}:${config.port}`);
  console.log(`[media] public signaling url=${config.registry.publicUrl}`);
  console.log(
    `[media] mediasoup listenIp=${config.mediasoup.listenIp} announcedIp=${config.mediasoup.announcedIp} rtcPorts=${config.mediasoup.minPort}-${config.mediasoup.maxPort}`,
  );
  heartbeatLoop.start();
});

async function shutdown(signal: string, exitCode = 0) {
  if (shuttingDown) return;
  shuttingDown = true;
  draining = true;
  console.log(`[media] received ${signal}; draining process.`);
  try {
    await markMediaNodeDraining();
  } catch (error) {
    console.error('[media] failed to mark node draining', error);
  }
  const deadline = Date.now() + (exitCode ? 5000 : config.drainTimeoutMs);
  while (roomManager.getStats().peerCount > 0 && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  if (roomManager.getStats().peerCount > 0) {
    console.error('[media] drain deadline reached with active peers', roomManager.getStats());
  }
  heartbeatLoop.stop();
  // An in-flight heartbeat must finish before unregistering, or it could
  // resurrect this node after the offline request.
  await heartbeatLoop.waitForIdle().catch(() => undefined);
  try {
    await markMediaNodeOffline();
  } catch (error) {
    console.error('[media] failed to unregister node cleanly', error);
  }
  io.close();
  workerManager.close();
  httpServer.close(() => process.exit(exitCode));
  setTimeout(() => process.exit(exitCode || 1), 5000).unref();
}

workerManager.onDied(() => void shutdown('mediasoup worker died', 1));
process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));
