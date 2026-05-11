require('dotenv').config();

const http = require('http');
const express = require('express');
const cors = require('cors');
const { WebSocketServer } = require('ws');
const { rooms, getOrCreateRoom, roomSnapshot, roomBlockAction } = require('./roomState');
const handlers = require('./roomHandlers');

const host = process.env.MEDIA_SERVER_HOST || '0.0.0.0';
const port = Number(process.env.MEDIA_SERVER_PORT || 9000);

const app = express();
app.use(cors());
app.use(express.json());

function log(type, payload = {}) {
  console.log(`[${new Date().toISOString()}] ${type}`, payload);
}

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'vibematch-media-server', rooms: rooms.size });
});

app.get('/rooms/:roomId', (req, res) => {
  const room = rooms.get(req.params.roomId);
  if (!room) return res.status(404).json({ detail: 'Room not found' });
  return res.json(roomSnapshot(room));
});

app.post('/rooms/:roomId', (req, res) => {
  const room = getOrCreateRoom(req.params.roomId);
  return res.json(roomSnapshot(room));
});

const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

wss.on('connection', (ws) => {
  let currentRoom = null;
  let currentPeer = null;

  const setSession = (room, peer) => {
    currentRoom = room;
    currentPeer = peer;
  };

  const clearSession = () => {
    currentRoom = null;
    currentPeer = null;
  };

  const requireRoom = () => {
    if (!currentRoom || !currentPeer) {
      handlers.send(ws, 'error', { detail: 'Join a room before sending room events.' });
      return false;
    }
    return true;
  };

  log('ws/connected');
  handlers.send(ws, 'media/connected', {
    server_time: new Date().toISOString(),
    message: 'Connected to Vibe Match media signaling server.',
  });

  ws.on('message', (raw) => {
    let message;
    try {
      message = JSON.parse(raw.toString());
    } catch (_error) {
      handlers.send(ws, 'error', { detail: 'Invalid JSON message.' });
      return;
    }

    const type = String(message.type || 'unknown');
    const payload = message.payload || {};
    log('event/received', { type, payload });

    try {
      if (type === 'room/join') return handlers.joinRoom({ ws, payload, setSession });
      if (!requireRoom()) return;

      if (type === 'room/leave') return handlers.leaveRoom({ ws, room: currentRoom, peer: currentPeer, clearSession });
      if (type === 'room_settings/apply_mode') return handlers.setRoomApplyMode({ room: currentRoom, peer: currentPeer, payload });
      if (type === 'seat_invite/send') return handlers.sendSeatInvite({ ws, room: currentRoom, peer: currentPeer, payload });
      if (type === 'seat_application/request') return handlers.requestSeatApplication({ ws, room: currentRoom, peer: currentPeer, payload });
      if (type === 'admin/seat_assign') return handlers.adminAssignSeat({ room: currentRoom, payload });
      if (type === 'seat/take') return handlers.takeSeat({ ws, room: currentRoom, peer: currentPeer, payload });
      if (type === 'seat/leave') return handlers.leaveSeat({ room: currentRoom, peer: currentPeer });
      if (type === 'mic/set_enabled') return handlers.setMic({ room: currentRoom, peer: currentPeer, payload });
      if (type === 'admin_mute/set') return handlers.setAdminMute({ room: currentRoom, payload });
      if (type === 'room_admin/set') return handlers.setRoomAdminStatus({ room: currentRoom, peer: currentPeer, payload });
      if (type === 'admin/seat_leave') return handlers.adminSeatLeave({ room: currentRoom, peer: currentPeer, payload });
      if (type === 'admin/seat_lock') return handlers.setSeatLock({ room: currentRoom, payload, locked: true });
      if (type === 'admin/seat_unlock') return handlers.setSeatLock({ room: currentRoom, payload, locked: false });
      if (type === 'admin/seat_leave_lock') return handlers.adminSeatLeaveLock({ room: currentRoom, peer: currentPeer, payload });
      if (type === `admin/${roomBlockAction}`) return handlers.adminBlockUser({ room: currentRoom, peer: currentPeer, payload });
      if (type === `admin/${roomBlockAction}_remove`) return handlers.removeRoomBlock({ ws, room: currentRoom, peer: currentPeer, payload });
      if (type === 'webrtc/offer' || type === 'webrtc/answer' || type === 'webrtc/ice_candidate') return handlers.relayWebRtc({ ws, room: currentRoom, peer: currentPeer, type, payload });
      if (type === 'room/chat') return handlers.roomChat({ room: currentRoom, peer: currentPeer, payload });

      handlers.send(ws, 'error', { detail: `Unsupported event type: ${type}` });
    } catch (error) {
      log('event/error', { type, detail: error.message || 'Unhandled media server error.' });
      handlers.send(ws, 'error', { detail: error.message || 'Unhandled media server error.' });
    }
  });

  ws.on('close', () => {
    if (!currentRoom || !currentPeer) {
      log('ws/closed_without_room');
      return;
    }
    handlers.peerClosed(currentRoom, currentPeer);
    clearSession();
  });
});

server.listen(port, host, () => {
  console.log(`Vibe Match media server running on http://${host}:${port}`);
});
