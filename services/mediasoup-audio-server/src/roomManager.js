const config = require('./config');
const {
  assignWorkerForRoom,
  decrementWorkerRoomCount,
  getWorkerStats,
  incrementWorkerRoomCount,
} = require('./mediasoupServer');

const rooms = new Map();

function createSeatMap() {
  const seats = new Map();

  for (let index = 1; index <= config.maxSpeakersPerRoom; index += 1) {
    seats.set(index, {
      seatNo: index,
      peerId: null,
      producerId: null,
      selfMuted: false,
      adminMuted: false,
    });
  }

  return seats;
}

function getRoomStats() {
  const roomStats = Array.from(rooms.values()).map((room) => ({
    id: room.id,
    workerIndex: room.worker.appData.index,
    peerCount: room.peers.size,
    speakerCount: Array.from(room.seats.values()).filter((seat) => Boolean(seat.peerId)).length,
    producerCount: Array.from(room.peers.values()).reduce((count, peer) => count + peer.producers.size, 0),
    consumerCount: Array.from(room.peers.values()).reduce((count, peer) => count + peer.consumers.size, 0),
    createdAt: room.createdAt.toISOString(),
  }));

  return {
    roomCount: rooms.size,
    maxRooms: config.maxRooms,
    maxSpeakersPerRoom: config.maxSpeakersPerRoom,
    maxRoomPeers: config.maxRoomPeers,
    workers: getWorkerStats(),
    rooms: roomStats,
  };
}

async function getOrCreateRoom(roomId) {
  let room = rooms.get(roomId);

  if (room) {
    return room;
  }

  if (rooms.size >= config.maxRooms) {
    throw new Error(`server room limit reached: ${config.maxRooms}`);
  }

  const worker = assignWorkerForRoom();
  const router = await worker.createRouter({
    mediaCodecs: config.mediasoup.router.mediaCodecs,
  });

  room = {
    id: roomId,
    worker,
    router,
    peers: new Map(),
    seats: createSeatMap(),
    createdAt: new Date(),
  };

  rooms.set(roomId, room);
  incrementWorkerRoomCount(worker);

  console.log(`[room] created room=${roomId} worker=${worker.appData.index}`);

  return room;
}

function getRoom(roomId) {
  return rooms.get(roomId);
}

function createPeer(room, peerId, socketId) {
  if (room.peers.size >= config.maxRoomPeers) {
    throw new Error(`room peer limit reached: ${config.maxRoomPeers}`);
  }

  const peer = {
    id: peerId,
    socketId,
    joinedAt: new Date(),
    transports: new Map(),
    producers: new Map(),
    consumers: new Map(),
    seatNo: null,
  };

  room.peers.set(peerId, peer);
  return peer;
}

function getSeatSnapshot(room) {
  return Array.from(room.seats.values()).map((seat) => ({
    seatNo: seat.seatNo,
    peerId: seat.peerId,
    producerId: seat.producerId,
    selfMuted: seat.selfMuted,
    adminMuted: seat.adminMuted,
  }));
}

function takeSeat(room, peerId, requestedSeatNo) {
  const peer = room.peers.get(peerId);
  if (!peer) throw new Error('peer not found');

  const seatNo = Number(requestedSeatNo);
  const seat = room.seats.get(seatNo);
  if (!seat) throw new Error(`invalid seat number. Allowed seats: 1-${config.maxSpeakersPerRoom}`);

  if (seat.peerId && seat.peerId !== peerId) {
    throw new Error(`seat ${seatNo} is already occupied`);
  }

  if (peer.seatNo && peer.seatNo !== seatNo) {
    leaveSeat(room, peerId);
  }

  seat.peerId = peerId;
  seat.selfMuted = false;
  seat.adminMuted = false;
  peer.seatNo = seatNo;

  return seat;
}

function leaveSeat(room, peerId) {
  const peer = room.peers.get(peerId);
  if (!peer || !peer.seatNo) return null;

  const seat = room.seats.get(peer.seatNo);
  if (!seat) {
    peer.seatNo = null;
    return null;
  }

  seat.peerId = null;
  seat.producerId = null;
  seat.selfMuted = false;
  seat.adminMuted = false;
  peer.seatNo = null;

  return seat;
}

function setSeatProducer(room, peerId, producerId) {
  const peer = room.peers.get(peerId);
  if (!peer || !peer.seatNo) {
    throw new Error('peer must take a seat before producing audio');
  }

  const seat = room.seats.get(peer.seatNo);
  if (!seat) throw new Error('seat not found');

  seat.producerId = producerId;
  return seat;
}

function setSelfMuted(room, peerId, muted) {
  const peer = room.peers.get(peerId);
  if (!peer || !peer.seatNo) throw new Error('peer is not seated');

  const seat = room.seats.get(peer.seatNo);
  if (!seat) throw new Error('seat not found');

  seat.selfMuted = Boolean(muted);
  return seat;
}

function setAdminMuted(room, targetPeerId, muted) {
  const peer = room.peers.get(targetPeerId);
  if (!peer || !peer.seatNo) throw new Error('target peer is not seated');

  const seat = room.seats.get(peer.seatNo);
  if (!seat) throw new Error('seat not found');

  seat.adminMuted = Boolean(muted);
  return seat;
}

function closeRoomIfEmpty(roomId, room) {
  if (!room || room.peers.size !== 0) {
    return room;
  }

  room.router.close();
  rooms.delete(roomId);
  decrementWorkerRoomCount(room.worker);
  console.log(`[room] closed empty room=${roomId} worker=${room.worker.appData.index}`);

  return null;
}

function removePeer(roomId, peerId) {
  const room = rooms.get(roomId);
  if (!room) return null;

  const peer = room.peers.get(peerId);
  if (!peer) return room;

  leaveSeat(room, peerId);

  for (const consumer of peer.consumers.values()) {
    consumer.close();
  }

  for (const producer of peer.producers.values()) {
    producer.close();
  }

  for (const transport of peer.transports.values()) {
    transport.close();
  }

  room.peers.delete(peerId);
  console.log(`[peer] removed peer=${peerId} room=${roomId}`);

  return closeRoomIfEmpty(roomId, room);
}

module.exports = {
  getOrCreateRoom,
  getRoom,
  getRoomStats,
  createPeer,
  removePeer,
  getSeatSnapshot,
  takeSeat,
  leaveSeat,
  setSeatProducer,
  setSelfMuted,
  setAdminMuted,
};
