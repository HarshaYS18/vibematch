require('dotenv').config();
const crypto = require('crypto');
const os = require('os');

const announcedIp = process.env.ANNOUNCED_IP || '127.0.0.1';
const turnHost = process.env.TURN_HOST || announcedIp;
const turnPort = Number(process.env.TURN_PORT || 3478);
const turnUsername = process.env.TURN_USERNAME || 'vibematch-local';
const turnPassword = process.env.TURN_PASSWORD || 'vibematch-local-password';

const maxSpeakersPerRoom = Number(process.env.MAX_SPEAKERS_PER_ROOM || 17);
const cpuCount = Math.max(1, os.cpus().length || 1);
const defaultWorkerCount = Math.min(cpuCount, 4);
const audioJwtSecret = process.env.AUDIO_JWT_SECRET_KEY || process.env.JWT_SECRET_KEY || 'change-this-secret-key-in-production';
const audioJwtAlgorithm = process.env.AUDIO_JWT_ALGORITHM || process.env.JWT_ALGORITHM || 'HS256';

function secretFingerprint(secret) {
  return crypto.createHash('sha256').update(secret).digest('hex').slice(0, 12);
}

module.exports = {
  port: Number(process.env.PORT || 4000),
  announcedIp,
  workerCount: Number(process.env.MEDIASOUP_WORKER_COUNT || defaultWorkerCount),
  maxRooms: Number(process.env.MAX_ROOMS || 500),
  maxSpeakersPerRoom,
  maxRoomPeers: Number(process.env.MAX_ROOM_PEERS || 250),
  roomIdleCleanupMs: Number(process.env.ROOM_IDLE_CLEANUP_MS || 600000),
  roomCleanupIntervalMs: Number(process.env.ROOM_CLEANUP_INTERVAL_MS || 60000),

  auth: {
    requireAudioToken: process.env.REQUIRE_AUDIO_TOKEN !== 'false',
    jwtSecret: audioJwtSecret,
    jwtAlgorithm: audioJwtAlgorithm,
    secretFingerprint: secretFingerprint(audioJwtSecret),
  },

  iceServers: [
    {
      urls: [`stun:${turnHost}:${turnPort}`],
    },
    {
      urls: [`turn:${turnHost}:${turnPort}?transport=udp`, `turn:${turnHost}:${turnPort}?transport=tcp`],
      username: turnUsername,
      credential: turnPassword,
    },
  ],

  mediasoup: {
    worker: {
      rtcMinPort: Number(process.env.RTC_MIN_PORT || 40000),
      rtcMaxPort: Number(process.env.RTC_MAX_PORT || 49999),
      logLevel: 'warn',
      logTags: ['info', 'ice', 'dtls', 'rtp', 'srtp', 'rtcp'],
    },

    router: {
      mediaCodecs: [
        {
          kind: 'audio',
          mimeType: 'audio/opus',
          clockRate: 48000,
          channels: 2,
          preferredPayloadType: 111,
          parameters: {
            useinbandfec: 1,
            usedtx: 1,
          },
        },
      ],
    },

    webRtcTransport: {
      listenIps: [
        {
          ip: '0.0.0.0',
          announcedIp,
        },
      ],
      enableUdp: true,
      enableTcp: true,
      preferUdp: true,
      initialAvailableOutgoingBitrate: 350000,
      minimumAvailableOutgoingBitrate: 120000,
      maxSctpMessageSize: 262144,
    },
  },
};
