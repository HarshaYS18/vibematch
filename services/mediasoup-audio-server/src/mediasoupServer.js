const mediasoup = require('mediasoup');
const config = require('./config');

let worker;

async function createWorker() {
  worker = await mediasoup.createWorker({
    logLevel: config.mediasoup.worker.logLevel,
    logTags: config.mediasoup.worker.logTags,
    rtcMinPort: config.mediasoup.worker.rtcMinPort,
    rtcMaxPort: config.mediasoup.worker.rtcMaxPort,
  });

  console.log(`[mediasoup] worker created pid=${worker.pid}`);

  worker.on('died', () => {
    console.error('[mediasoup] worker died. Exiting so the process manager can restart it.');
    setTimeout(() => process.exit(1), 2000);
  });

  return worker;
}

function getWorker() {
  if (!worker) {
    throw new Error('mediasoup worker not created yet');
  }

  return worker;
}

module.exports = {
  createWorker,
  getWorker,
};
