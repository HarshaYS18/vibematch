import { randomUUID } from 'node:crypto';
import { spawn, type ChildProcessWithoutNullStreams } from 'node:child_process';
import type { Server } from 'socket.io';
import type { types } from 'mediasoup';

import type { RoomState } from '../types/mediaTypes.js';

const SERVER_MUSIC_PEER_ID = 'server-room-music';

type ActiveMusic = {
  id: string;
  producer: types.Producer;
  transport: types.PlainTransport;
  ffmpeg: ChildProcessWithoutNullStreams;
  title: string;
  url: string;
  controllerPeerId: string;
  startedAt: string;
  seekMs: number;
};

const activeMusicByRoom = new Map<string, ActiveMusic>();

function randomSsrc(): number {
  return Math.floor(100000000 + Math.random() * 3000000000);
}

export async function startRoomMusic(params: {
  room: RoomState;
  io: Server;
  controllerPeerId: string;
  url: string;
  title: string;
  seekMs?: number;
}): Promise<Record<string, unknown>> {
  const safeUrl = params.url.trim();
  if (!safeUrl) throw new Error('Room music URL is required.');

  await stopRoomMusic(params.room, params.io, 'replace');

  const router = params.room.router as unknown as types.Router;
  const transport = await router.createPlainTransport({
    listenIp: { ip: process.env.PLAIN_TRANSPORT_LISTEN_IP || '127.0.0.1' },
    rtcpMux: true,
    comedia: true,
  });

  const ssrc = randomSsrc();
  const title = params.title.trim() || 'Room music';
  const seekMs = Math.max(0, Math.floor(params.seekMs ?? 0));
  const producer = await transport.produce({
    kind: 'audio',
    rtpParameters: {
      codecs: [{
        mimeType: 'audio/opus',
        payloadType: 111,
        clockRate: 48000,
        channels: 2,
        parameters: { useinbandfec: 1 },
        rtcpFeedback: [],
      }],
      encodings: [{ ssrc }],
      rtcp: { cname: `room-music-${params.room.roomPublicId}` },
    },
    appData: {
      source: 'server-room-music',
      mediaTag: 'room-music-audio',
      title,
      url: safeUrl,
    },
  });

  const port = transport.tuple.localPort;
  const seekSeconds = seekMs / 1000;
  const ffmpegArgs = [
    '-hide_banner',
    '-loglevel', process.env.FFMPEG_LOG_LEVEL || 'warning',
    ...(seekSeconds > 0 ? ['-ss', String(seekSeconds)] : []),
    '-re',
    '-i', safeUrl,
    '-vn',
    '-ac', '2',
    '-ar', '48000',
    '-c:a', 'libopus',
    '-b:a', process.env.ROOM_MUSIC_BITRATE || '96k',
    '-payload_type', '111',
    '-ssrc', String(ssrc),
    '-f', 'rtp',
    `rtp://127.0.0.1:${port}?pkt_size=1200`,
  ];
  const ffmpeg = spawn(process.env.FFMPEG_PATH || 'ffmpeg', ffmpegArgs, {
    windowsHide: true,
  });

  const state: ActiveMusic = {
    id: randomUUID(),
    producer,
    transport,
    ffmpeg,
    title,
    url: safeUrl,
    controllerPeerId: params.controllerPeerId,
    startedAt: new Date().toISOString(),
    seekMs,
  };
  activeMusicByRoom.set(params.room.roomPublicId, state);
  params.room.serverProducers.set(producer.id, {
    producer,
    peerId: SERVER_MUSIC_PEER_ID,
    appData: { ...producer.appData },
  });

  ffmpeg.stderr.on('data', (chunk) => {
    const line = chunk.toString().trim();
    if (line) console.log(`[media:music:${params.room.roomPublicId}] ${line}`);
  });
  ffmpeg.on('exit', () => {
    const current = activeMusicByRoom.get(params.room.roomPublicId);
    if (current?.id !== state.id) return;
    void stopRoomMusic(params.room, params.io, 'ffmpeg-exit');
  });
  ffmpeg.on('error', (error) => {
    console.error('[media:music] ffmpeg failed', error);
    const current = activeMusicByRoom.get(params.room.roomPublicId);
    if (current?.id === state.id) void stopRoomMusic(params.room, params.io, 'ffmpeg-error');
  });
  producer.on('transportclose', () => {
    if (!ffmpeg.killed) ffmpeg.kill('SIGTERM');
  });

  const producerPayload = {
    roomId: params.room.roomPublicId,
    producerId: producer.id,
    id: producer.id,
    peerId: SERVER_MUSIC_PEER_ID,
    kind: 'audio',
    appData: { ...producer.appData },
  };
  params.io.to(params.room.roomPublicId).emit('newProducer', producerPayload);

  const publicState = {
    active: true,
    id: state.id,
    producerId: producer.id,
    controllerPeerId: state.controllerPeerId,
    title,
    url: safeUrl,
    startedAt: state.startedAt,
    seekMs,
  };
  params.io.to(params.room.roomPublicId).emit('roomMusicStarted', {
    roomId: params.room.roomPublicId,
    music: publicState,
  });
  return publicState;
}

export async function stopRoomMusic(
  room: RoomState,
  io: Server,
  reason = 'stopped',
): Promise<void> {
  const current = activeMusicByRoom.get(room.roomPublicId);
  if (!current) return;
  activeMusicByRoom.delete(room.roomPublicId);

  try {
    if (!current.ffmpeg.killed) current.ffmpeg.kill('SIGTERM');
  } catch { /* Process may already have exited. */ }
  try {
    if (!current.producer.closed) current.producer.close();
  } catch { /* Producer may already be closed with its router. */ }
  try {
    if (!current.transport.closed) current.transport.close();
  } catch { /* Transport may already be closed with its worker. */ }

  room.serverProducers.delete(current.producer.id);
  io.to(room.roomPublicId).emit('producerClosed', {
    producerId: current.producer.id,
    peerId: SERVER_MUSIC_PEER_ID,
    reason,
  });
  io.to(room.roomPublicId).emit('roomMusicStopped', {
    roomId: room.roomPublicId,
    reason,
  });
}
