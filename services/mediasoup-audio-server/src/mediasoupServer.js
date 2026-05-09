const mediasoup = require('mediasoup');
const config = require('./config');

const workers = [];
let nextWorkerIndex = 0;

async function createSingleWorker(index) {
  const worker = await mediasoup.createWorker({
    logLevel: config.mediasoup.worker.logLevel,
    logTags: config.mediasoup.worker.logTags,
    rtcMinPort: config.mediasoup.worker.rtcMinPort,
    rtcMaxPort: config.mediasoup.worker.rtcMaxPort,
  });

  worker.appData = {
    index,
    roomCount: 0,
  };

  console.log(`[mediasoup] worker created index=${index} pid=${worker.pid}`);

  worker.on('died', () => {
    console.error(`[mediasoup] worker died index=${index} pid=${worker.pid}`);
  });

  return worker;
}

async function createWorkers() {
  if (workers.length > 0) {
    return workers;
  }

  for (let index = 0; index < config.workerCount; index += 1) {
    const worker = await createSingleWorker(index);
    workers.push(worker);
  }

  return workers;
}

function getLeastLoadedWorker() {
  if (workers.length === 0) {
    throw new Error('mediasoup workers not created yet');
  }

  let selected = workers[0];

  for (const worker of workers) {
    if ((worker.appData.roomCount || 0) < (selected.appData.roomCount || 0)) {
      selected = worker;
    }
  }

  return selected;
}

function getRoundRobinWorker() {
  if (workers.length === 0) {
    throw new Error('mediasoup workers not created yet');
  }

  const worker = workers[nextWorkerIndex];
  nextWorkerIndex = (nextWorkerIndex + 1) % workers.length;
  return worker;
}

function assignWorkerForRoom() {
  const leastLoadedWorker = getLeastLoadedWorker();
  const roundRobinWorker = getRoundRobinWorker();

  const leastLoadedCount = leastLoadedWorker.appData.roomCount || 0;
  const roundRobinCount = roundRobinWorker.appData.roomCount || 0;

  return leastLoadedCount <= roundRobinCount ? leastLoadedWorker : roundRobinWorker;
}

function incrementWorkerRoomCount(worker) {
  worker.appData.roomCount = (worker.appData.roomCount || 0) + 1;
}

function decrementWorkerRoomCount(worker) {
  worker.appData.roomCount = Math.max(0, (worker.appData.roomCount || 0) - 1);
}

function getWorkerStats() {
  return workers.map((worker) => ({
    index: worker.appData.index,
    pid: worker.pid,
    roomCount: worker.appData.roomCount || 0,
    closed: worker.closed,
  }));
}

module.exports = {
  createWorkers,
  assignWorkerForRoom,
  incrementWorkerRoomCount,
  decrementWorkerRoomCount,
  getWorkerStats,
};
