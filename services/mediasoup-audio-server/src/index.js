const cors = require('cors');
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const config = require('./config');
const { createWorkers } = require('./mediasoupServer');
const { cleanupStaleRooms, getRoomStats } = require('./roomManager');
const { registerSocketHandlers } = require('./socketHandlers');

async function main() {
  await createWorkers();

  const app = express();
  app.use(cors());
  app.use(express.json());

  app.get('/health', (req, res) => {
    const stats = getRoomStats();

    res.json({
      ok: true,
      service: 'vibematch-mediasoup-audio-server',
      mode: 'small-beta-multi-room',
      announcedIp: config.announcedIp,
      workerCount: config.workerCount,
      maxRooms: config.maxRooms,
      maxSpeakersPerRoom: config.maxSpeakersPerRoom,
      maxRoomPeers: config.maxRoomPeers,
      roomCount: stats.roomCount,
      uptimeSeconds: stats.uptimeSeconds,
    });
  });

  app.get('/ready', (req, res) => {
    const stats = getRoomStats();
    const roomCapacityOk = stats.roomCount < config.maxRooms;
    const workersOk = stats.workers.length === config.workerCount && stats.workers.every((worker) => worker.closed === false);
    const ok = roomCapacityOk && workersOk;

    res.status(ok ? 200 : 503).json({
      ok,
      roomCapacityOk,
      workersOk,
      workerCount: config.workerCount,
      roomCount: stats.roomCount,
      maxRooms: config.maxRooms,
    });
  });

  app.get('/stats', (req, res) => {
    res.json({
      ok: true,
      ...getRoomStats(),
    });
  });

  const server = http.createServer(app);
  const io = new Server(server, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
    transports: ['websocket', 'polling'],
  });

  registerSocketHandlers(io);

  setInterval(() => {
    const closedCount = cleanupStaleRooms();
    if (closedCount > 0) {
      console.log(`[cleanup] closed stale rooms count=${closedCount}`);
    }
  }, config.roomCleanupIntervalMs).unref();

  server.listen(config.port, '0.0.0.0', () => {
    console.log(`[server] VibeMatch mediasoup small-beta audio SFU listening on 0.0.0.0:${config.port}`);
    console.log(`[server] workerCount=${config.workerCount}`);
    console.log(`[server] maxRooms=${config.maxRooms}`);
    console.log(`[server] maxSpeakersPerRoom=${config.maxSpeakersPerRoom}`);
    console.log(`[server] announcedIp=${config.announcedIp}`);
  });
}

main().catch((error) => {
  console.error('[server] startup error', error);
});
