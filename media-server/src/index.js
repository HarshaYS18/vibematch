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

function getOrCreateRoom(roomId) {
  const id = String(roomId || '').trim();
  if (!id) throw new Error('room_id is required');

  let room = rooms.get(id);
  if (!room) {
    room = {
      id,
      peers: new Map(),
      createdAt: new Date().toISOString(),
    };
    rooms.set(id, room);
  }
  return room;
}

function roomSnapshot(room) {
  return {
    room_id: room.id,
    created_at: room.createdAt,
    peer_count: room.peers.size,
    peers: Array.from(room.peers.values()).map((peer) => ({
      peer_id: peer.id,
      user_id: peer.userId,
      display_name: peer.displayName,
      seat_index: peer.seatIndex,
      mic_enabled: peer.micEnabled,
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

  send(ws, 'media/connected', {
    server_time: new Date().toISOString(),
    message: 'Connected to Vibe Match media signaling server.',
  });

  ws.on('message', (raw) => {
    let message;
    try {
      message = JSON.parse(raw.toString());
    } catch (_error) {
      send(ws, 'error', { detail: 'Invalid JSON message.' });
      return;
    }

    const type = message.type;
    const payload = message.payload || {};

    try {
      if (type === 'room/join') {
        const room = getOrCreateRoom(payload.room_id);
        const peer = {
          id: payload.peer_id || randomUUID(),
          userId: String(payload.user_id || 'guest'),
          displayName: String(payload.display_name || 'Vibe User'),
          seatIndex: payload.seat_index ?? null,
          micEnabled: false,
          joinedAt: new Date().toISOString(),
          ws,
        };

        currentRoom = room;
        currentPeer = peer;
        room.peers.set(peer.id, peer);

        send(ws, 'room/joined', {
          peer_id: peer.id,
          room: roomSnapshot(room),
        });

        broadcast(room, 'room/peer_joined', {
          peer_id: peer.id,
          user_id: peer.userId,
          display_name: peer.displayName,
          room: roomSnapshot(room),
        }, peer.id);
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
        broadcast(room, 'room/peer_left', { peer_id: peer.id, room: roomSnapshot(room) });
        send(ws, 'room/left', { peer_id: peer.id });
        if (room.peers.size === 0) rooms.delete(room.id);
        currentRoom = null;
        currentPeer = null;
        return;
      }

      if (type === 'seat/take') {
        currentPeer.seatIndex = payload.seat_index;
        broadcast(currentRoom, 'seat/updated', {
          peer_id: currentPeer.id,
          user_id: currentPeer.userId,
          seat_index: currentPeer.seatIndex,
          room: roomSnapshot(currentRoom),
        });
        return;
      }

      if (type === 'seat/leave') {
        currentPeer.seatIndex = null;
        currentPeer.micEnabled = false;
        broadcast(currentRoom, 'seat/updated', {
          peer_id: currentPeer.id,
          user_id: currentPeer.userId,
          seat_index: null,
          mic_enabled: false,
          room: roomSnapshot(currentRoom),
        });
        return;
      }

      if (type === 'mic/set_enabled') {
        currentPeer.micEnabled = Boolean(payload.enabled) && currentPeer.seatIndex != null;
        broadcast(currentRoom, 'mic/updated', {
          peer_id: currentPeer.id,
          user_id: currentPeer.userId,
          mic_enabled: currentPeer.micEnabled,
          room: roomSnapshot(currentRoom),
        });
        return;
      }

      if (type === 'webrtc/offer' || type === 'webrtc/answer' || type === 'webrtc/ice_candidate') {
        const targetPeerId = payload.target_peer_id;
        const target = currentRoom.peers.get(targetPeerId);
        if (!target) {
          send(ws, 'error', { detail: 'Target peer not found for WebRTC signaling.' });
          return;
        }
        send(target.ws, type, {
          ...payload,
          from_peer_id: currentPeer.id,
          from_user_id: currentPeer.userId,
        });
        return;
      }

      if (type === 'room/chat') {
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

      send(ws, 'error', { detail: `Unsupported event type: ${type}` });
    } catch (error) {
      send(ws, 'error', { detail: error.message || 'Unhandled media server error.' });
    }
  });

  ws.on('close', () => {
    if (!currentRoom || !currentPeer) return;
    const room = currentRoom;
    const peer = currentPeer;
    room.peers.delete(peer.id);
    broadcast(room, 'room/peer_left', { peer_id: peer.id, room: roomSnapshot(room) });
    if (room.peers.size === 0) rooms.delete(room.id);
  });
});

server.listen(port, host, () => {
  console.log(`Vibe Match media server running on http://${host}:${port}`);
});
