require('dotenv').config();

const http = require('http');
const express = require('express');
const cors = require('cors');
const { Server } = require('socket.io');

const {
  rooms,
  getOrCreateRoom,
  createPeer,
  snapshotRoom,
  takeSeat,
  leaveSeat,
  setSelfMuted,
  cleanupPeer,
} = require('./roomStore');

const {
  createWorkerAndRouter,
  createWebRtcTransport,
  transportParams,
} = require('./mediasoupService');

const {
  startRoomMusic,
  stopRoomMusic,
} = require('./musicSourceManager');

const host = process.env.AUDIO_SERVER_HOST || '0.0.0.0';
const port = Number(process.env.AUDIO_SERVER_PORT || 4000);

const app = express();
app.use(cors());
app.use(express.json({ limit: '2mb' }));

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

let routerPromise = createWorkerAndRouter();

function ackOk(extra = {}) {
  return { ok: true, ...extra };
}

function ackError(error) {
  return { ok: false, error: error?.message || String(error || 'Unknown error') };
}

async function getRoom(roomId) {
  const router = await routerPromise;
  return getOrCreateRoom(roomId, router);
}

function getPeerRoom(socket) {
  const roomId = socket.data.roomId;
  const peerId = socket.data.peerId;
  if (!roomId || !peerId) throw new Error('Join room first');
  const room = rooms.get(roomId);
  if (!room) throw new Error('Room not found');
  const peer = room.peers.get(peerId);
  if (!peer) throw new Error('Peer not found');
  return { room, peer };
}

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    service: 'vibematch-audio-sfu-server',
    rooms: rooms.size,
  });
});

app.post('/rooms/:roomId/music/start', async (req, res) => {
  try {
    const room = await getRoom(req.params.roomId);
    const music = await startRoomMusic({
      room,
      router: room.router,
      io,
      controllerPeerId: req.body.controllerPeerId || 'server-api',
      url: req.body.url,
      title: req.body.title || 'Room music',
    });
    res.json({ ok: true, music });
  } catch (error) {
    res.status(400).json(ackError(error));
  }
});

app.post('/rooms/:roomId/music/stop', async (req, res) => {
  try {
    const room = await getRoom(req.params.roomId);
    await stopRoomMusic(room, io);
    res.json({ ok: true });
  } catch (error) {
    res.status(400).json(ackError(error));
  }
});

io.on('connection', (socket) => {
  console.log(`[AudioSFU] connected ${socket.id}`);

  socket.on('joinRoom', async (payload, callback = () => {}) => {
    try {
      const roomId = String(payload?.roomId || '').trim();
      const peerId = String(payload?.peerId || '').trim();
      if (!roomId || !peerId) throw new Error('roomId and peerId are required');

      const room = await getRoom(roomId);
      const peer = createPeer(room, peerId);

      socket.data.roomId = room.id;
      socket.data.peerId = peer.id;
      socket.join(room.id);

      callback(ackOk({
        rtpCapabilities: room.router.rtpCapabilities,
        room: snapshotRoom(room),
      }));

      socket.to(room.id).emit('peerJoined', {
        roomId: room.id,
        peerId: peer.id,
      });
    } catch (error) {
      callback(ackError(error));
    }
  });

  socket.on('createWebRtcTransport', async (payload, callback = () => {}) => {
    try {
      const { room, peer } = getPeerRoom(socket);
      const transport = await createWebRtcTransport(room.router);

      room.transports.set(transport.id, {
        transport,
        peerId: peer.id,
        direction: payload?.direction || 'unknown',
      });
      peer.transports.add(transport.id);

      transport.on('dtlsstatechange', (state) => {
        if (state === 'closed') {
          try {
            transport.close();
          } catch (_) {}
        }
      });

      callback(ackOk({ params: transportParams(transport) }));
    } catch (error) {
      callback(ackError(error));
    }
  });

  socket.on('connectTransport', async (payload, callback = () => {}) => {
    try {
      const { room } = getPeerRoom(socket);
      const record = room.transports.get(String(payload?.transportId || ''));
      if (!record) throw new Error('Transport not found');

      await record.transport.connect({
        dtlsParameters: payload.dtlsParameters,
      });

      callback(ackOk());
    } catch (error) {
      callback(ackError(error));
    }
  });

  socket.on('produce', async (payload, callback = () => {}) => {
    try {
      const { room, peer } = getPeerRoom(socket);
      const record = room.transports.get(String(payload?.transportId || ''));
      if (!record) throw new Error('Transport not found');

      const producer = await record.transport.produce({
        kind: payload.kind,
        rtpParameters: payload.rtpParameters,
        appData: payload.appData || { mediaTag: 'mic-audio' },
      });

      room.producers.set(producer.id, {
        producer,
        peerId: peer.id,
        source: producer.appData?.mediaTag || 'mic-audio',
      });
      peer.producers.add(producer.id);

      producer.on('transportclose', () => {
        room.producers.delete(producer.id);
        peer.producers.delete(producer.id);
      });

      socket.to(room.id).emit('newProducer', {
        roomId: room.id,
        producerId: producer.id,
        peerId: peer.id,
        kind: producer.kind,
        appData: producer.appData || {},
      });

      callback(ackOk({ producerId: producer.id, id: producer.id }));
    } catch (error) {
      callback(ackError(error));
    }
  });

  socket.on('consume', async (payload, callback = () => {}) => {
    try {
      const { room, peer } = getPeerRoom(socket);
      const transportRecord = room.transports.get(String(payload?.transportId || ''));
      if (!transportRecord) throw new Error('Transport not found');

      const producerId = String(payload?.producerId || '');
      const producerRecord = room.producers.get(producerId);
      if (!producerRecord) throw new Error('Producer not found');

      if (!room.router.canConsume({
        producerId,
        rtpCapabilities: payload.rtpCapabilities,
      })) {
        throw new Error('Client cannot consume this producer');
      }

      const consumer = await transportRecord.transport.consume({
        producerId,
        rtpCapabilities: payload.rtpCapabilities,
        paused: false,
      });

      room.consumers.set(consumer.id, {
        consumer,
        peerId: peer.id,
        producerId,
      });
      peer.consumers.add(consumer.id);

      consumer.on('transportclose', () => {
        room.consumers.delete(consumer.id);
        peer.consumers.delete(consumer.id);
      });

      consumer.on('producerclose', () => {
        room.consumers.delete(consumer.id);
        peer.consumers.delete(consumer.id);
        socket.emit('producerClosed', { producerId });
      });

      callback(ackOk({
        params: {
          id: consumer.id,
          producerId,
          kind: consumer.kind,
          rtpParameters: consumer.rtpParameters,
        },
      }));
    } catch (error) {
      callback(ackError(error));
    }
  });

  socket.on('resumeConsumer', async (payload, callback = () => {}) => {
    try {
      const { room, peer } = getPeerRoom(socket);
      const consumerId = String(payload?.consumerId || '');
      if (!consumerId) throw new Error('consumerId is required');

      const record = room.consumers.get(consumerId);
      if (!record) throw new Error('Consumer not found');
      if (record.peerId !== peer.id) {
        throw new Error('Consumer does not belong to this peer');
      }

      await record.consumer.resume();

      console.log('[AudioSFU] consumer resumed', {
        roomId: room.id,
        peerId: peer.id,
        consumerId,
        producerId: record.producerId,
      });

      callback(ackOk());
    } catch (error) {
      console.error('[AudioSFU] resumeConsumer failed', error);
      callback(ackError(error));
    }
  });

  socket.on('takeSeat', (payload, callback = () => {}) => {
    try {
      const { room, peer } = getPeerRoom(socket);
      takeSeat(room, peer.id, payload?.seatNo);
      io.to(room.id).emit('seatsUpdated', {
        roomId: room.id,
        seats: room.seats,
      });
      callback(ackOk({ seats: room.seats }));
    } catch (error) {
      callback(ackError(error));
    }
  });

  socket.on('leaveSeat', (_payload, callback = () => {}) => {
    try {
      const { room, peer } = getPeerRoom(socket);
      leaveSeat(room, peer.id);
      io.to(room.id).emit('seatsUpdated', {
        roomId: room.id,
        seats: room.seats,
      });
      callback(ackOk({ seats: room.seats }));
    } catch (error) {
      callback(ackError(error));
    }
  });

  socket.on('setSelfMuted', (payload, callback = () => {}) => {
    try {
      const { room, peer } = getPeerRoom(socket);
      setSelfMuted(room, peer.id, payload?.muted === true);
      io.to(room.id).emit('seatsUpdated', {
        roomId: room.id,
        seats: room.seats,
      });
      callback(ackOk({ seats: room.seats }));
    } catch (error) {
      callback(ackError(error));
    }
  });

  socket.on('startRoomMusic', async (payload, callback = () => {}) => {
    try {
      const { room, peer } = getPeerRoom(socket);
      console.log('[AudioSFU] startRoomMusic request', {
        roomId: room.id,
        peerId: peer.id,
        title: payload?.title,
        url: payload?.url,
      });

      const music = await startRoomMusic({
        room,
        router: room.router,
        io,
        controllerPeerId: peer.id,
        url: payload?.url,
        title: payload?.title || 'Room music',
      });

      console.log('[AudioSFU] startRoomMusic ok', {
        roomId: room.id,
        producerId: music?.producerId,
        title: music?.title,
      });

      callback(ackOk({ music }));
    } catch (error) {
      console.error('[AudioSFU] startRoomMusic failed', error);
      callback(ackError(error));
    }
  });

  socket.on('stopRoomMusic', async (_payload, callback = () => {}) => {
    try {
      const { room } = getPeerRoom(socket);
      await stopRoomMusic(room, io);
      callback(ackOk());
    } catch (error) {
      callback(ackError(error));
    }
  });

  socket.on('disconnect', () => {
    const roomId = socket.data.roomId;
    const peerId = socket.data.peerId;
    if (!roomId || !peerId) return;

    const room = rooms.get(roomId);
    if (!room) return;

    cleanupPeer(room, peerId);
    socket.to(room.id).emit('peerLeft', {
      roomId: room.id,
      peerId,
      room: snapshotRoom(room),
    });
    io.to(room.id).emit('seatsUpdated', {
      roomId: room.id,
      seats: room.seats,
    });
  });
});

server.listen(port, host, () => {
  console.log(`[AudioSFU] running on http://${host}:${port}`);
});
