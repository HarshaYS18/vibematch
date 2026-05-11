const { randomUUID } = require('crypto');

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

function broadcastRoomSystemEvent(room, payload = {}, exceptPeerId = null) {
  const event = {
    id: randomUUID(),
    room_id: room.id,
    created_at: new Date().toISOString(),
    ...payload,
  };
  broadcast(room, 'room/system_event', event, exceptPeerId);
  return event;
}

function userEnteredEvent(peer) {
  return {
    event_type: 'user_entered',
    actor_user_id: peer.userId,
    actor_name: peer.displayName,
    target_user_id: peer.userId,
    target_name: peer.displayName,
    auto_dismiss_seconds: 5,
  };
}

function userRemovedEvent(actorPeer, targetPeer) {
  return {
    event_type: 'user_removed',
    actor_user_id: actorPeer.userId,
    actor_name: actorPeer.displayName,
    target_user_id: targetPeer.userId,
    target_name: targetPeer.displayName,
  };
}

module.exports = {
  broadcastRoomSystemEvent,
  userEnteredEvent,
  userRemovedEvent,
};
