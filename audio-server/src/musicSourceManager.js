const { spawn } = require('child_process');
const { randomUUID } = require('crypto');

const activeMusicByRoom = new Map();

function startProducerStatsLogger(roomId, producer) {
  let ticks = 0;
  const timer = setInterval(async () => {
    ticks += 1;
    try {
      const stats = await producer.getStats();
      const compact = Array.from(stats.values ? stats.values() : stats).map((item) => ({
        type: item.type,
        kind: item.kind,
        packetsReceived: item.packetsReceived,
        bytesReceived: item.bytesReceived,
        bitrate: item.bitrate,
        score: item.score,
      }));
      console.log(`[RoomMusic:${roomId}] producer stats`, compact);
    } catch (error) {
      console.error(`[RoomMusic:${roomId}] producer stats failed`, error);
      clearInterval(timer);
    }

    if (ticks >= 10 || producer.closed) clearInterval(timer);
  }, 2000);

  return timer;
}

function randomSsrc() {
  return Math.floor(100000000 + Math.random() * 3000000000);
}

async function stopRoomMusic(room, io) {
  const current = activeMusicByRoom.get(room.id);
  if (!current) return;

  activeMusicByRoom.delete(room.id);

  try {
    if (current.statsTimer) clearInterval(current.statsTimer);
  } catch (_) {}

  try {
    current.ffmpeg.kill('SIGTERM');
  } catch (_) {}

  try {
    current.producer.close();
  } catch (_) {}

  try {
    current.transport.close();
  } catch (_) {}

  room.producers.delete(current.producer.id);
  room.music = {
    active: false,
    producerId: null,
    controllerPeerId: null,
    title: '',
    url: '',
    startedAt: null,
  };

  io.to(room.id).emit('producerClosed', {
    producerId: current.producer.id,
    roomId: room.id,
  });

  io.to(room.id).emit('roomMusicStopped', {
    roomId: room.id,
    room: {
      id: room.id,
      music: room.music,
    },
  });
}

async function startRoomMusic({ room, router, io, controllerPeerId, url, title }) {
  const safeUrl = String(url || '').trim();
  if (!safeUrl) throw new Error('Room music URL is required');

  await stopRoomMusic(room, io);

  const plainTransport = await router.createPlainTransport({
    listenIp: {
      ip: process.env.PLAIN_TRANSPORT_LISTEN_IP || '127.0.0.1',
      announcedIp: undefined,
    },
    rtcpMux: true,
    comedia: true,
  });

  const ssrc = randomSsrc();

  const producer = await plainTransport.produce({
    kind: 'audio',
    rtpParameters: {
      codecs: [
        {
          mimeType: 'audio/opus',
          payloadType: 111,
          clockRate: 48000,
          channels: 2,
          parameters: {
            useinbandfec: 1,
          },
          rtcpFeedback: [],
        },
      ],
      encodings: [{ ssrc }],
      rtcp: {
        cname: `room-music-${room.id}`,
      },
    },
    appData: {
      source: 'server-room-music',
      mediaTag: 'room-music-audio',
      title: String(title || 'Room music'),
      url: safeUrl,
    },
  });

  room.producers.set(producer.id, {
    producer,
    peerId: 'server-room-music',
    source: 'server-room-music',
  });

  const port = plainTransport.tuple.localPort;
  const ffmpegArgs = [
    '-hide_banner',
    '-loglevel',
    process.env.FFMPEG_LOG_LEVEL || 'warning',
    '-re',
    '-i',
    safeUrl,
    '-vn',
    '-ac',
    '2',
    '-ar',
    '48000',
    '-c:a',
    'libopus',
    '-b:a',
    process.env.ROOM_MUSIC_BITRATE || '96k',
    '-payload_type',
    '111',
    '-ssrc',
    String(ssrc),
    '-f',
    'rtp',
    `rtp://127.0.0.1:${port}?pkt_size=1200`,
  ];

  const ffmpeg = spawn(process.env.FFMPEG_PATH || 'ffmpeg', ffmpegArgs, {
    windowsHide: true,
  });

  ffmpeg.stderr.on('data', (chunk) => {
    const line = chunk.toString().trim();
    if (line) console.log(`[RoomMusic:${room.id}] ${line}`);
  });

  ffmpeg.on('exit', (code, signal) => {
    const current = activeMusicByRoom.get(room.id);
    if (!current || current.producer.id !== producer.id) return;

    console.log(`[RoomMusic:${room.id}] ffmpeg exited code=${code} signal=${signal}`);
    activeMusicByRoom.delete(room.id);

    try {
      producer.close();
    } catch (_) {}

    try {
      plainTransport.close();
    } catch (_) {}

    room.producers.delete(producer.id);
    room.music = {
      active: false,
      producerId: null,
      controllerPeerId: null,
      title: '',
      url: '',
      startedAt: null,
    };

    io.to(room.id).emit('producerClosed', {
      producerId: producer.id,
      roomId: room.id,
    });
    io.to(room.id).emit('roomMusicStopped', {
      roomId: room.id,
      room: {
        id: room.id,
        music: room.music,
      },
    });
  });

  producer.on('transportclose', () => {
    try {
      ffmpeg.kill('SIGTERM');
    } catch (_) {}
  });

  const musicId = randomUUID();
  room.music = {
    active: true,
    id: musicId,
    producerId: producer.id,
    controllerPeerId: controllerPeerId || 'server-room-music',
    title: String(title || 'Room music'),
    url: safeUrl,
    startedAt: new Date().toISOString(),
  };

  activeMusicByRoom.set(room.id, {
    id: musicId,
    producer,
    transport: plainTransport,
    ffmpeg,
    statsTimer: startProducerStatsLogger(room.id, producer),
  });

  io.to(room.id).emit('newProducer', {
    roomId: room.id,
    producerId: producer.id,
    peerId: 'server-room-music',
    kind: 'audio',
    appData: producer.appData,
  });

  io.to(room.id).emit('roomMusicStarted', {
    roomId: room.id,
    music: room.music,
  });

  return room.music;
}

module.exports = {
  startRoomMusic,
  stopRoomMusic,
};
