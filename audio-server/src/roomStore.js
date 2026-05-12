const { randomUUID } = require('crypto');

const rooms = new Map();

function createSeatSnapshot(seatNo, peerId = null) {
  return {
    seatNo,
    peerId,
    muted: true,
    adminMuted: false,
  };
}

function getOrCreateRoom(roomId, router) {
  const id = String(roomId || '').trim();
  if (!id) throw new Error('roomId is required');

  let room = rooms.get(id);
  if (!room) {
    room = {
      id,
      router,
      peers: new Map(),
      producers: new Map(),
      consumers: new Map(),
      transports: new Map(),
      seats: Array.from({ length: 20 }, (_, index) => createSeatSnapshot(index + 1)),
      music: {
        active: false,
        producerId: null,
        controllerPeerId: null,
        title: '',
        url: '',
        startedAt: null,
      },
      createdAt: new Date().toISOString(),
    };
    rooms.set(id, room);
  }

  return room;
}

function createPeer(room, peerId) {
  const id = String(peerId || randomUUID()).trim();
  let peer = room.peers.get(id);
  if (!peer) {
    peer = {
      id,
      transports: new Set(),
      producers: new Set(),
      consumers: new Set(),
      joinedAt: new Date().toISOString(),
    };
    room.peers.set(id, peer);
  }
  return peer;
}

function snapshotRoom(room) {
  return {
    id: room.id,
    seats: room.seats,
    producers: Array.from(room.producers.values()).map((producerRecord) => ({
      producerId: producerRecord.producer.id,
      peerId: producerRecord.peerId,
      kind: producerRecord.producer.kind,
      appData: producerRecord.producer.appData || {},
    })),
    music: room.music,
  };
}

function seatForPeer(room, peerId) {
  return room.seats.find((seat) => seat.peerId === peerId) || null;
}

function takeSeat(room, peerId, seatNo) {
  const safeSeatNo = Number(seatNo);
  if (!Number.isInteger(safeSeatNo) || safeSeatNo < 1 || safeSeatNo > room.seats.length) {
    throw new Error('Invalid seat number');
  }

  for (const seat of room.seats) {
    if (seat.peerId === peerId) {
      seat.peerId = null;
      seat.muted = true;
      seat.adminMuted = false;
    }
  }

  const target = room.seats[safeSeatNo - 1];
  if (target.peerId && target.peerId !== peerId) {
    throw new Error('Seat already occupied');
  }

  target.peerId = peerId;
  target.muted = false;
  target.adminMuted = false;
  return target;
}

function leaveSeat(room, peerId) {
  const seat = seatForPeer(room, peerId);
  if (!seat) return null;
  seat.peerId = null;
  seat.muted = true;
  seat.adminMuted = false;
  return seat;
}

function setSelfMuted(room, peerId, muted) {
  const seat = seatForPeer(room, peerId);
  if (!seat) return null;
  if (seat.adminMuted) {
    seat.muted = true;
    return seat;
  }
  seat.muted = Boolean(muted);
  return seat;
}

function cleanupPeer(room, peerId) {
  const peer = room.peers.get(peerId);
  if (!peer) return;

  leaveSeat(room, peerId);

  for (const producerId of Array.from(peer.producers)) {
    const record = room.producers.get(producerId);
    try {
      record?.producer?.close();
    } catch (_) {}
    room.producers.delete(producerId);
  }

  for (const consumerId of Array.from(peer.consumers)) {
    const record = room.consumers.get(consumerId);
    try {
      record?.consumer?.close();
    } catch (_) {}
    room.consumers.delete(consumerId);
  }

  for (const transportId of Array.from(peer.transports)) {
    const record = room.transports.get(transportId);
    try {
      record?.transport?.close();
    } catch (_) {}
    room.transports.delete(transportId);
  }

  room.peers.delete(peerId);
}

module.exports = {
  rooms,
  getOrCreateRoom,
  createPeer,
  snapshotRoom,
  takeSeat,
  leaveSeat,
  setSelfMuted,
  cleanupPeer,
};
