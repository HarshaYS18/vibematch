const cors = require('cors');
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const config = require('./config');
const { createWorker } = require('./mediasoupServer');
const { registerSocketHandlers } = require('./socketHandlers');

async function main() {
  await createWorker();

  const app = express();
  app.use(cors());
  app.use(express.json());

  app.get('/health', (req, res) => {
    res.json({
      ok: true,
      service: 'vibematch-mediasoup-audio-server',
      mode: 'standalone-poc',
      maxSpeakersPerRoom: config.maxSpeakersPerRoom,
      announcedIp: config.announcedIp,
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
    console.log(`[server] VibeMatch mediasoup audio SFU listening on 0.0.0.0:${config.port}`);
    console.log(`[server] maxSpeakersPerRoom=${config.maxSpeakersPerRoom}`);
    console.log(`[server] announcedIp=${config.announcedIp}`);
  });
}

main().catch((error) => {
  console.error('[server] startup error', error);
});
