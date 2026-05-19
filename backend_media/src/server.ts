import http from 'node:http';
import cors from 'cors';
import express from 'express';
import { config } from './config.js';
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
    service: 'vibematch-media-service',
    fastApiBaseUrl: config.fastApiBaseUrl,
  });
});

app.get('/', (_request, response) => {
  response.json({
    service: 'vibematch-media-service',
    status: 'ok',
    signaling: 'socket.io',
    sourceOfTruth: 'FastAPI /media-realtime/verify',
  });
});

const httpServer = http.createServer(app);
const io = createSocketServer(httpServer, roomManager);

httpServer.listen(config.port, config.host, () => {
  console.log(`[media] service running on http://${config.host}:${config.port}`);
  console.log(
    `[media] mediasoup listenIp=${config.mediasoup.listenIp} announcedIp=${config.mediasoup.announcedIp} rtcPorts=${config.mediasoup.minPort}-${config.mediasoup.maxPort}`,
  );
});

async function shutdown(signal: string) {
  console.log(`[media] received ${signal}; shutting down.`);
  io.close();
  workerManager.close();
  httpServer.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 5000).unref();
}

process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));
