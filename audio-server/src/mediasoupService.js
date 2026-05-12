const mediasoup = require('mediasoup');

const announcedIp = process.env.ANNOUNCED_IP || undefined;
const listenIp = process.env.LISTEN_IP || '0.0.0.0';

const mediaCodecs = [
  {
    kind: 'audio',
    mimeType: 'audio/opus',
    clockRate: 48000,
    channels: 2,
    preferredPayloadType: 111,
    parameters: {
      useinbandfec: 1,
    },
  },
];

let worker;
let router;

async function createWorkerAndRouter() {
  if (router) return router;

  worker = await mediasoup.createWorker({
    rtcMinPort: Number(process.env.RTC_MIN_PORT || 40000),
    rtcMaxPort: Number(process.env.RTC_MAX_PORT || 49999),
    logLevel: process.env.MEDIASOUP_LOG_LEVEL || 'warn',
    logTags: ['info', 'ice', 'dtls', 'rtp', 'srtp', 'rtcp'],
  });

  worker.on('died', () => {
    console.error('[AudioSFU] mediasoup worker died; exiting in 2 seconds');
    setTimeout(() => process.exit(1), 2000);
  });

  router = await worker.createRouter({ mediaCodecs });
  return router;
}

async function createWebRtcTransport(routerInstance) {
  const transport = await routerInstance.createWebRtcTransport({
    listenIps: [
      {
        ip: listenIp,
        announcedIp,
      },
    ],
    enableUdp: true,
    enableTcp: true,
    preferUdp: true,
    initialAvailableOutgoingBitrate: 600000,
  });

  return transport;
}

function transportParams(transport) {
  return {
    id: transport.id,
    iceParameters: transport.iceParameters,
    iceCandidates: transport.iceCandidates,
    dtlsParameters: transport.dtlsParameters,
    sctpParameters: transport.sctpParameters,
  };
}

module.exports = {
  createWorkerAndRouter,
  createWebRtcTransport,
  transportParams,
};
