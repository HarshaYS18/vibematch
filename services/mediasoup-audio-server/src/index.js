const cors = require('cors');
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const config = require('./config');
const { createWorkers } = require('./mediasoupServer');
const { getRoomStats } = require('./roomManager');
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
      mode: 'standalone-multi-room-poc',
      announcedIp: config.announcedIp,
      workerCount: config.workerCount,
      maxRooms: config.maxRooms,
      maxSpeakersPerRoom: config.maxSpeakersPerRoom,
      maxRoomPeers: config.maxRoomPeers,
      roomCount: stats.roomCount,
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

  server.listen(config.port, '0.0.0.0', () => {
    console.log(`[server] VibeMatch mediasoup multi-room audio SFU listening on 0.0.0.0:${config.port}`);
    console.log(`[server] workerCount=${config.workerCount}`);
    console.log(`[server] maxRooms=${config.maxRooms}`);
    console.log(`[server] maxSpeakersPerRoom=${config.maxSpeakersPerRoom}`);
    console.log(`[server] announcedIp=${config.announcedIp}`);
  });
}

main().catch((error) => {
  console.error('[server] startup error', error);
});
