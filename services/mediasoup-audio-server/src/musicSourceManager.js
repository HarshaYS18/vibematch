const { randomUUID } = require('crypto');
const { spawn } = require('child_process');

const SERVER_MUSIC_PEER_ID = 'server-room-music';

function randomSsrc() {
  return Math.floor(100000000 + Math.random() * 3000000000);
}

function defaultMusicState() {
  return {
    active: false,
    id: null,
    producerId: null,
    controllerPeerId: null,
    title: '',
    url: '',
    startedAt: null,
  };
}

function ensureRoomMusicState(room) {
  if (!room.music) {
    room.music = {
      state: defaultMusicState(),
      producer: null,
      transport: null,
      ffmpeg: null,
      statsTimer: null,
    };
  }
  return room.music;
}

function startProducerStatsLogger(roomId, producer) {
  let ticks = 0;
  const timer = setInterval(async () => {
    ticks += 1;
    try {
      const stats = await producer.getStats();
      const values = Array.from(stats.values ? stats.values() : stats);
      const compact = values.map((item) => ({
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

  timer.unref?.();
  return timer;
}

async function stopRoomMusic(room, io, reason = 'stopped') {
  const music = ensureRoomMusicState(room);
  const producerId = music.producer?.id || music.state.producerId;

  try {
    if (music.statsTimer) clearInterval(music.statsTimer);
  } catch (_) {}

  try {
    if (music.ffmpeg && !music.ffmpeg.killed) music.ffmpeg.kill('SIGTERM');
  } catch (_) {}

  try {
    if (music.producer && !music.producer.closed) music.producer.close();
  } catch (_) {}

  try {
    if (music.transport && !music.transport.closed) music.transport.close();
  } catch (_) {}

  room.music = {
    state: defaultMusicState(),
    producer: null,
    transport: null,
    ffmpeg: null,
    statsTimer: null,
  };

  if (producerId) {
    io.to(room.id).emit('producerClosed', {
      producerId,
      peerId: SERVER_MUSIC_PEER_ID,
      reason,
    });
  }

  io.to(room.id).emit('roomMusicStopped', {
    roomId: room.id,
    reason,
    music: room.music.state,
  });
}

async function startRoomMusic({ room, io, controllerPeerId, url, title, seekMs = 0 }) {
  const safeUrl = String(url || '').trim();
  if (!safeUrl) throw new Error('Room music URL is required');

  await stopRoomMusic(room, io, 'replace');

  const plainTransport = await room.router.createPlainTransport({
    listenIp: {
      ip: process.env.PLAIN_TRANSPORT_LISTEN_IP || '127.0.0.1',
      announcedIp: undefined,
    },
    rtcpMux: true,
    comedia: true,
  });

  const ssrc = randomSsrc();
  const safeTitle = String(title || 'Room music').trim() || 'Room music';
  const safeSeekSeconds = Math.max(0, Number(seekMs || 0) / 1000);

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
      title: safeTitle,
      url: safeUrl,
    },
  });

  const port = plainTransport.tuple.localPort;
  const ffmpegArgs = [
    '-hide_banner',
    '-loglevel',
    process.env.FFMPEG_LOG_LEVEL || 'warning',
    ...(safeSeekSeconds > 0 ? ['-ss', String(safeSeekSeconds)] : []),
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
    const current = ensureRoomMusicState(room);
    if (current.producer?.id !== producer.id) return;

    console.log(`[RoomMusic:${room.id}] ffmpeg exited code=${code} signal=${signal}`);
    stopRoomMusic(room, io, 'ffmpeg-exit').catch((error) => {
      console.error(`[RoomMusic:${room.id}] stop after ffmpeg exit failed`, error);
    });
  });

  producer.on('transportclose', () => {
    try {
      if (!ffmpeg.killed) ffmpeg.kill('SIGTERM');
    } catch (_) {}
  });

  producer.on('close', () => {
    try {
      if (!ffmpeg.killed) ffmpeg.kill('SIGTERM');
    } catch (_) {}
  });

  const state = {
    active: true,
    id: randomUUID(),
    producerId: producer.id,
    controllerPeerId: controllerPeerId || SERVER_MUSIC_PEER_ID,
    title: safeTitle,
    url: safeUrl,
    startedAt: new Date().toISOString(),
    seekMs: Math.floor(safeSeekSeconds * 1000),
  };

  room.music = {
    state,
    producer,
    transport: plainTransport,
    ffmpeg,
    statsTimer: startProducerStatsLogger(room.id, producer),
  };

  const payload = {
    roomId: room.id,
    producerId: producer.id,
    peerId: SERVER_MUSIC_PEER_ID,
    kind: 'audio',
    appData: producer.appData,
  };

  io.to(room.id).emit('newProducer', payload);
  io.to(room.id).emit('roomMusicStarted', {
    roomId: room.id,
    music: state,
  });

  console.log('[RoomMusic] started', {
    roomId: room.id,
    producerId: producer.id,
    controllerPeerId: state.controllerPeerId,
    title: safeTitle,
  });

  return state;
}

module.exports = {
  SERVER_MUSIC_PEER_ID,
  ensureRoomMusicState,
  startRoomMusic,
  stopRoomMusic,
};
