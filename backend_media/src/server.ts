import http from 'node:http';
import cors from 'cors';
import express from 'express';
import { config } from './config.js';
import { markMediaNodeOffline, heartbeatMediaNode, registryIsHealthy, RegistryRequestError } from './control/registryClient.js';
import { HeartbeatLoop } from './control/heartbeatLoop.js';
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

async function sendHeartbeat(): Promise<void> {
  if (shuttingDown || !workerManager.isReady) return;
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

let shuttingDown = false;
async function shutdown(signal: string, exitCode = 0) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`[media] received ${signal}; draining process.`);
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
