require('dotenv').config();

const http = require('http');
const express = require('express');
const cors = require('cors');
const { WebSocketServer } = require('ws');
const { randomUUID } = require('crypto');

const host = process.env.MEDIA_SERVER_HOST || '0.0.0.0';
const port = Number(process.env.MEDIA_SERVER_PORT || 9000);

const app = express();
app.use(cors());
app.use(express.json());

const rooms = new Map();

function log(type, payload = {}) {
  const time = new Date().toISOString();
  console.log(`[${time}] ${type}`, payload);
}

function getOrCreateRoom(roomId) {
  const id = String(roomId || '').trim();
  if (!id) throw new Error('room_id is required');

  let room = rooms.get(id);
  if (!room) {
    room = { id, peers: new Map(), lockedSeatIndexes: new Set(), createdAt: new Date().toISOString() };
    rooms.set(id, room);
    log('room/created', { room_id: id });
  }
  if (!room.lockedSeatIndexes) room.lockedSeatIndexes = new Set();
  return room;
}

function normalizeSeatIndex(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) return null;
  return parsed;
}

function roomSnapshot(room) {
  return {
    room_id: room.id,
    created_at: room.createdAt,
    peer_count: room.peers.size,
    locked_seat_indexes: Array.from(room.lockedSeatIndexes || []),
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

function send(ws, type, payload = {}) {
  if (ws.readyState !== ws.OPEN) return;
  ws.send(JSON.stringify({ type, payload }));
}

function broadcast(room, type, payload = {}, exceptPeerId = null) {
  for (const peer of room.peers.values()) {
    if (exceptPeerId != null && peer.id === exceptPeerId) continue;
    send(peer.ws, type, payload);
  }
}

function broadcastSnapshot(room, type, payload = {}, exceptPeerId = null) {
  broadcast(room, type, { ...payload, room: roomSnapshot(room) }, exceptPeerId);
}

function findPeerByUserId(room, userId) {
  const targetUserId = String(userId || '').trim();
  if (!targetUserId) return null;
  for (const peer of room.peers.values()) {
    if (peer.userId === targetUserId || peer.id === targetUserId) return peer;
  }
  return null;
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

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'vibematch-media-server', rooms: rooms.size });
});

app.get('/rooms/:roomId', (req, res) => {
  const room = rooms.get(req.params.roomId);
  if (!room) {
    res.status(404).json({ detail: 'Room not found' });
    return;
  }
  res.json(roomSnapshot(room));
});

app.post('/rooms/:roomId', (req, res) => {
  const room = getOrCreateRoom(req.params.roomId);
  res.json(roomSnapshot(room));
});

const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

wss.on('connection', (ws) => {
  let currentRoom = null;
  let currentPeer = null;

  log('ws/connected');
  send(ws, 'media/connected', {
    server_time: new Date().toISOString(),
    message: 'Connected to Vibe Match media signaling server.',
  });

  ws.on('message', (raw) => {
    let message;
    try {
      message = JSON.parse(raw.toString());
    } catch (_error) {
      log('ws/error_invalid_json', { raw: raw.toString().slice(0, 200) });
      send(ws, 'error', { detail: 'Invalid JSON message.' });
      return;
    }

    const type = message.type;
    const payload = message.payload || {};
    log('event/received', { type, payload });

    try {
      if (type === 'room/join') {
        const room = getOrCreateRoom(payload.room_id);
        const peer = {
          id: payload.peer_id || randomUUID(),
          userId: String(payload.user_id || 'guest'),
          displayName: String(payload.display_name || 'Vibe User'),
          seatIndex: payload.seat_index ?? null,
          micEnabled: false,
          adminMuted: false,
          joinedAt: new Date().toISOString(),
          ws,
        };

        currentRoom = room;
        currentPeer = peer;
        room.peers.set(peer.id, peer);
        log('room/joined', { room_id: room.id, peer_id: peer.id, user_id: peer.userId, display_name: peer.displayName, peer_count: room.peers.size });

        send(ws, 'room/joined', { peer_id: peer.id, room: roomSnapshot(room) });
        broadcast(room, 'room/peer_joined', { peer_id: peer.id, user_id: peer.userId, display_name: peer.displayName, room: roomSnapshot(room) }, peer.id);
        return;
      }

      if (!currentRoom || !currentPeer) {
        send(ws, 'error', { detail: 'Join a room before sending room events.' });
        return;
      }

      if (type === 'room/leave') {
        const room = currentRoom;
        const peer = currentPeer;
        room.peers.delete(peer.id);
        log('room/left', { room_id: room.id, peer_id: peer.id, peer_count: room.peers.size });
        broadcast(room, 'room/peer_left', { peer_id: peer.id, room: roomSnapshot(room) });
        send(ws, 'room/left', { peer_id: peer.id });
        if (room.peers.size === 0) rooms.delete(room.id);
        currentRoom = null;
        currentPeer = null;
        return;
      }

      if (type === 'seat/take') {
        const seatIndex = normalizeSeatIndex(payload.seat_index);
        if (seatIndex == null) throw new Error('seat_index is required');
        if (currentRoom.lockedSeatIndexes.has(seatIndex)) throw new Error(`Seat ${seatIndex + 1} is locked`);
        clearSeatOccupant(currentRoom, seatIndex);
        currentPeer.seatIndex = seatIndex;
        currentPeer.adminMuted = false;
        log('seat/take', { room_id: currentRoom.id, peer_id: currentPeer.id, seat_index: currentPeer.seatIndex });
        broadcastSnapshot(currentRoom, 'seat/updated', { peer_id: currentPeer.id, user_id: currentPeer.userId, seat_index: currentPeer.seatIndex });
        return;
      }

      if (type === 'seat/leave') {
        clearPeerSeat(currentPeer);
        log('seat/leave', { room_id: currentRoom.id, peer_id: currentPeer.id });
        broadcastSnapshot(currentRoom, 'seat/updated', { peer_id: currentPeer.id, user_id: currentPeer.userId, seat_index: null, mic_enabled: false });
        return;
      }

      if (type === 'mic/set_enabled') {
        currentPeer.micEnabled = Boolean(payload.enabled) && currentPeer.seatIndex != null && currentPeer.adminMuted !== true;
        log('mic/set_enabled', { room_id: currentRoom.id, peer_id: currentPeer.id, mic_enabled: currentPeer.micEnabled });
        broadcastSnapshot(currentRoom, 'mic/updated', { peer_id: currentPeer.id, user_id: currentPeer.userId, mic_enabled: currentPeer.micEnabled });
        return;
      }

      if (type === 'admin_mute/set') {
        const target = findPeerByUserId(currentRoom, payload.target_user_id);
        if (!target) throw new Error('Target user not found for admin mute');
        target.adminMuted = Boolean(payload.muted);
        if (target.adminMuted) target.micEnabled = false;
        log('admin_mute/set', { room_id: currentRoom.id, admin_peer_id: currentPeer.id, target_peer_id: target.id, target_user_id: target.userId, muted: target.adminMuted });
        broadcastSnapshot(currentRoom, 'admin_mute/updated', { peer_id: target.id, user_id: target.userId, admin_muted: target.adminMuted, mic_enabled: target.micEnabled });
        return;
      }

      if (type === 'admin/seat_leave') {
        const target = findPeerByUserId(currentRoom, payload.target_user_id);
        if (!target) throw new Error('Target user not found for seat leave');
        clearPeerSeat(target);
        log('admin/seat_leave', { room_id: currentRoom.id, admin_peer_id: currentPeer.id, target_peer_id: target.id, target_user_id: target.userId });
        broadcastSnapshot(currentRoom, 'seat/updated', { peer_id: target.id, user_id: target.userId, seat_index: null, mic_enabled: false });
        return;
      }

      if (type === 'admin/seat_lock') {
        const seatIndex = normalizeSeatIndex(payload.seat_index);
        if (seatIndex == null) throw new Error('seat_index is required');
        clearSeatOccupant(currentRoom, seatIndex);
        currentRoom.lockedSeatIndexes.add(seatIndex);
        log('admin/seat_lock', { room_id: currentRoom.id, admin_peer_id: currentPeer.id, seat_index: seatIndex });
        broadcastSnapshot(currentRoom, 'seat/locked', { seat_index: seatIndex, locked: true });
        return;
      }

      if (type === 'admin/seat_unlock') {
        const seatIndex = normalizeSeatIndex(payload.seat_index);
        if (seatIndex == null) throw new Error('seat_index is required');
        currentRoom.lockedSeatIndexes.delete(seatIndex);
        log('admin/seat_unlock', { room_id: currentRoom.id, admin_peer_id: currentPeer.id, seat_index: seatIndex });
        broadcastSnapshot(currentRoom, 'seat/locked', { seat_index: seatIndex, locked: false });
        return;
      }

      if (type === 'admin/seat_leave_lock') {
        const seatIndex = normalizeSeatIndex(payload.seat_index);
        if (seatIndex == null) throw new Error('seat_index is required');
        const target = findPeerByUserId(currentRoom, payload.target_user_id);
        if (target) clearPeerSeat(target);
        clearSeatOccupant(currentRoom, seatIndex);
        currentRoom.lockedSeatIndexes.add(seatIndex);
        log('admin/seat_leave_lock', { room_id: currentRoom.id, admin_peer_id: currentPeer.id, target_peer_id: target?.id, seat_index: seatIndex });
        broadcastSnapshot(currentRoom, 'seat/locked', { peer_id: target?.id, user_id: target?.userId, seat_index: seatIndex, locked: true });
        return;
      }

      if (type === 'admin/kick') {
        const target = findPeerByUserId(currentRoom, payload.target_user_id);
        if (!target) throw new Error('Target user not found for kick');
        currentRoom.peers.delete(target.id);
        log('admin/kick', { room_id: currentRoom.id, admin_peer_id: currentPeer.id, target_peer_id: target.id, target_user_id: target.userId, reason: payload.reason });
        send(target.ws, 'room/kicked', { peer_id: target.id, user_id: target.userId, reason: payload.reason || 'Removed by room admin' });
        try { target.ws.close(); } catch (_error) {}
        broadcastSnapshot(currentRoom, 'room/peer_left', { peer_id: target.id, user_id: target.userId });
        if (currentRoom.peers.size === 0) rooms.delete(currentRoom.id);
        return;
      }

      if (type === 'webrtc/offer' || type === 'webrtc/answer' || type === 'webrtc/ice_candidate') {
        const targetPeerId = payload.target_peer_id;
        const target = currentRoom.peers.get(targetPeerId);
        if (!target) {
          send(ws, 'error', { detail: 'Target peer not found for WebRTC signaling.' });
          return;
        }
        log(type, { room_id: currentRoom.id, from_peer_id: currentPeer.id, target_peer_id: targetPeerId });
        send(target.ws, type, { ...payload, from_peer_id: currentPeer.id, from_user_id: currentPeer.userId });
        return;
      }

      if (type === 'room/chat') {
        log('room/chat', { room_id: currentRoom.id, peer_id: currentPeer.id, text_length: String(payload.text || '').length });
        broadcast(currentRoom, 'room/chat', {
          id: randomUUID(),
          peer_id: currentPeer.id,
          user_id: currentPeer.userId,
          display_name: currentPeer.displayName,
          text: String(payload.text || '').slice(0, 500),
          created_at: new Date().toISOString(),
        });
        return;
      }

      log('event/unsupported', { type });
      send(ws, 'error', { detail: `Unsupported event type: ${type}` });
    } catch (error) {
      log('event/error', { type, detail: error.message || 'Unhandled media server error.' });
      send(ws, 'error', { detail: error.message || 'Unhandled media server error.' });
    }
  });

  ws.on('close', () => {
    if (!currentRoom || !currentPeer) {
      log('ws/closed_without_room');
      return;
    }
    const room = currentRoom;
    const peer = currentPeer;
    room.peers.delete(peer.id);
    log('ws/closed', { room_id: room.id, peer_id: peer.id, peer_count: room.peers.size });
    broadcast(room, 'room/peer_left', { peer_id: peer.id, room: roomSnapshot(room) });
    if (room.peers.size === 0) rooms.delete(room.id);
  });
});

server.listen(port, host, () => {
  console.log(`Vibe Match media server running on http://${host}:${port}`);
});
