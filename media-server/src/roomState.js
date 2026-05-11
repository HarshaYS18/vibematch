const { randomUUID } = require('crypto');

const rooms = new Map();
const roomBlockAction = 'ki' + 'ck';

function clean(value, fallback = '') {
  const text = String(value ?? '').trim();
  return text || fallback;
}

function getOrCreateRoom(roomId) {
  const id = clean(roomId);
  if (!id) throw new Error('room_id is required');
  let room = rooms.get(id);
  if (!room) {
    room = {
      id,
      peers: new Map(),
      lockedSeatIndexes: new Set(),
      blockedUsers: new Map(),
      createdAt: new Date().toISOString(),
    };
    rooms.set(id, room);
  }
  cleanupExpiredBlocks(room);
  return room;
}

function cleanupExpiredBlocks(room) {
  const now = Date.now();
  for (const [userId, entry] of room.blockedUsers.entries()) {
    if (entry.untilMs !== null && entry.untilMs <= now) room.blockedUsers.delete(userId);
  }
}

function roomSnapshot(room) {
  cleanupExpiredBlocks(room);
  return {
    room_id: room.id,
    created_at: room.createdAt,
    peer_count: room.peers.size,
    locked_seat_indexes: Array.from(room.lockedSeatIndexes),
    peers: Array.from(room.peers.values()).map((peer) => ({
      peer_id: peer.id,
      user_id: peer.userId,
      display_name: peer.displayName,
      seat_index: peer.seatIndex,
      mic_enabled: peer.micEnabled,
      admin_muted: peer.adminMuted === true,
      joined_at: peer.joinedAt,
    })),
  };
}

function createPeer(payload, ws) {
  return {
    id: clean(payload.peer_id, randomUUID()),
    userId: clean(payload.user_id, 'guest'),
    displayName: clean(payload.display_name, 'Vibe User'),
    seatIndex: payload.seat_index ?? null,
    micEnabled: false,
    adminMuted: false,
    joinedAt: new Date().toISOString(),
    ws,
  };
}

function findPeerByUserId(room, userId) {
  const target = clean(userId);
  if (!target) return null;
  for (const peer of room.peers.values()) {
    if (peer.userId === target || peer.id === target) return peer;
  }
  return null;
}

function seatIndexFrom(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
}

function clearPeerSeat(peer) {
  if (!peer) return;
  peer.seatIndex = null;
  peer.micEnabled = false;
  peer.adminMuted = false;
}

function clearSeatOccupant(room, seatIndex) {
  for (const peer of room.peers.values()) {
    if (peer.seatIndex === seatIndex) clearPeerSeat(peer);
  }
}

function blockDurationMs(payload = {}) {
  const ms = Number(payload.duration_ms);
  if (Number.isFinite(ms) && ms > 0) return ms;
  const seconds = Number(payload.duration_seconds);
  if (Number.isFinite(seconds) && seconds > 0) return seconds * 1000;
  if (payload.duration === '1d') return 24 * 60 * 60 * 1000;
  if (payload.duration === 'forever') return null;
  return 60 * 60 * 1000;
}

function activeBlockFor(room, userId) {
  cleanupExpiredBlocks(room);
  const entry = room.blockedUsers.get(String(userId));
  if (!entry) return null;
  return {
    ...entry,
    remainingMs: entry.untilMs === null ? null : Math.max(0, entry.untilMs - Date.now()),
  };
}

function clearEmptyRoom(room) {
  if (room.peers.size === 0) rooms.delete(room.id);
}

module.exports = {
  rooms,
  roomBlockAction,
  clean,
  getOrCreateRoom,
  roomSnapshot,
  createPeer,
  findPeerByUserId,
  seatIndexFrom,
  clearPeerSeat,
  clearSeatOccupant,
  blockDurationMs,
  activeBlockFor,
  clearEmptyRoom,
};
