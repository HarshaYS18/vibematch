require('dotenv').config();

const announcedIp = process.env.ANNOUNCED_IP || '127.0.0.1';
const turnHost = process.env.TURN_HOST || announcedIp;
const turnPort = Number(process.env.TURN_PORT || 3478);
const turnUsername = process.env.TURN_USERNAME || 'vibematch-local';
const turnPassword = process.env.TURN_PASSWORD || 'vibematch-local-password';

const maxSpeakersPerRoom = Number(process.env.MAX_SPEAKERS_PER_ROOM || 17);

module.exports = {
  port: Number(process.env.PORT || 4000),
  announcedIp,
  maxSpeakersPerRoom,
  maxRoomPeers: Number(process.env.MAX_ROOM_PEERS || 250),

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
