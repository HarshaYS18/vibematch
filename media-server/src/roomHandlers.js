const { randomUUID } = require('crypto');
const {
  roomBlockAction,
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
} = require('./roomState');
const {
  broadcastRoomSystemEvent,
  userEnteredEvent,
  userRemovedEvent,
} = require('./roomSystemEvents');

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

function broadcastSnapshot(room, type, payload = {}) {
  broadcast(room, type, { ...payload, room: roomSnapshot(room) });
}

function joinRoom({ ws, payload, setSession }) {
  const room = getOrCreateRoom(payload.room_id);
  const userId = String(payload.user_id || 'guest');
  const block = activeBlockFor(room, userId);
  if (block) {
    send(ws, 'room/join_blocked', {
      room_id: room.id,
      user_id: userId,
      reason: block.reason || 'Room access blocked.',
      kicked_until: block.untilMs === null ? null : new Date(block.untilMs).toISOString(),
      remaining_ms: block.remainingMs,
    });
    try { ws.close(); } catch (_error) {}
    return;
  }

  const peer = createPeer(payload, ws);
  room.peers.set(peer.id, peer);
  setSession(room, peer);

  send(ws, 'room/joined', { peer_id: peer.id, room: roomSnapshot(room) });
  broadcast(room, 'room/peer_joined', {
    peer_id: peer.id,
    user_id: peer.userId,
    display_name: peer.displayName,
    room: roomSnapshot(room),
  }, peer.id);
  broadcastRoomSystemEvent(room, userEnteredEvent(peer), peer.id);
}

function leaveRoom({ ws, room, peer, clearSession }) {
  room.peers.delete(peer.id);
  broadcast(room, 'room/peer_left', {
    peer_id: peer.id,
    user_id: peer.userId,
    display_name: peer.displayName,
    room: roomSnapshot(room),
  });
  send(ws, 'room/left', { peer_id: peer.id });
  clearEmptyRoom(room);
  clearSession();
}

function setRoomApplyMode({ room, peer, payload }) {
  room.applyOnlyModeEnabled = payload.apply_only_mode_enabled === true || payload.applyOnlyModeEnabled === true || payload.enabled === true;
  broadcast(room, 'room_settings/updated', {
    id: randomUUID(),
    room_id: room.id,
    actor_user_id: peer.userId,
    actor_name: peer.displayName,
    apply_only_mode_enabled: room.applyOnlyModeEnabled,
    room: roomSnapshot(room),
    created_at: new Date().toISOString(),
  });
}

function sendSeatInvite({ ws, room, peer, payload }) {
  const target = findPeerByUserId(room, payload.target_user_id);
  const seatIndex = seatIndexFrom(payload.seat_index);
  if (!target) throw new Error('Target user not found for seat invite');
  if (seatIndex == null) throw new Error('seat_index is required');
  if (target.id === peer.id || target.userId === peer.userId) throw new Error('Cannot invite yourself');
  if (target.seatIndex != null) throw new Error('Target user is already seated');
  if (room.lockedSeatIndexes.has(seatIndex)) throw new Error(`Seat ${seatIndex + 1} is locked`);
  send(target.ws, 'seat_invite/received', {
    invite_id: randomUUID(),
    room_id: room.id,
    seat_index: seatIndex,
    inviter_peer_id: peer.id,
    inviter_user_id: peer.userId,
    inviter_name: peer.displayName,
    target_user_id: target.userId,
    created_at: new Date().toISOString(),
  });
  send(ws, 'seat_invite/sent', { target_user_id: target.userId, seat_index: seatIndex });
}


function requestSeatApplication({ ws, room, peer, payload }) {
  const seatIndex = seatIndexFrom(payload.seat_index);
  if (seatIndex == null) throw new Error('seat_index is required');
  if (room.lockedSeatIndexes.has(seatIndex)) {
    send(ws, 'error', { detail: `Seat ${seatIndex + 1} is locked.` });
    return;
  }
  for (const item of room.peers.values()) {
    if (item.seatIndex === seatIndex) {
      send(ws, 'error', { detail: `Seat ${seatIndex + 1} is already occupied.` });
      return;
    }
  }

  const createdAt = new Date();
  const expiresAt = new Date(createdAt.getTime() + 20000);

  broadcast(room, 'seat_application/received', {
    id: randomUUID(),
    room_id: room.id,
    applicant_user_id: peer.userId,
    applicant_name: peer.displayName,
    seat_index: seatIndex,
    created_at: createdAt.toISOString(),
    expires_at: expiresAt.toISOString(),
  });
}

function adminAssignSeat({ room, payload }) {
  const seatIndex = seatIndexFrom(payload.seat_index);
  if (seatIndex == null) throw new Error('seat_index is required');

  const target = findPeerByUserId(room, payload.target_user_id);
  if (!target) throw new Error('Target user not found for seat assign');

  if (room.lockedSeatIndexes.has(seatIndex)) {
    throw new Error(`Seat ${seatIndex + 1} is locked`);
  }

  for (const peer of room.peers.values()) {
    if (peer.seatIndex === seatIndex && peer.userId !== target.userId) {
      throw new Error(`Seat ${seatIndex + 1} is already occupied`);
    }
  }

  target.seatIndex = seatIndex;
  target.adminMuted = false;

  broadcast(room, 'seat/updated', {
    peer_id: target.id,
    user_id: target.userId,
    seat_index: seatIndex,
    room: roomSnapshot(room),
  });
}

function takeSeat({ ws, room, peer, payload }) {
  const seatIndex = seatIndexFrom(payload.seat_index);
  if (seatIndex == null) throw new Error('seat_index is required');
  if (room.lockedSeatIndexes.has(seatIndex)) {
    send(ws, 'error', { detail: `Seat ${seatIndex + 1} is locked.` });
    return;
  }
  if (room.applyOnlyModeEnabled === true && peer.isRoomAdmin !== true && peer.isHost !== true) {
    send(ws, 'error', { detail: 'Apply Mode is enabled. Please apply for a seat.' });
    return;
  }
  peer.seatIndex = seatIndex;
  peer.adminMuted = false;
  broadcast(room, 'seat/updated', {
    peer_id: peer.id,
    user_id: peer.userId,
    seat_index: seatIndex,
    room: roomSnapshot(room),
  });
}

function leaveSeat({ room, peer }) {
  clearPeerSeat(peer);
  broadcast(room, 'seat/updated', {
    peer_id: peer.id,
    user_id: peer.userId,
    seat_index: null,
    mic_enabled: false,
    room: roomSnapshot(room),
  });
}

function setMic({ room, peer, payload }) {
  const enabled = Boolean(payload.enabled) && peer.seatIndex != null && peer.adminMuted !== true;
  peer.micEnabled = enabled;
  broadcast(room, peer.adminMuted ? 'admin_mute/updated' : 'mic/updated', {
    peer_id: peer.id,
    user_id: peer.userId,
    admin_muted: peer.adminMuted === true,
    mic_enabled: peer.micEnabled,
    room: roomSnapshot(room),
  });
}

function setAdminMute({ room, payload }) {
  const target = findPeerByUserId(room, payload.target_user_id);
  if (!target) throw new Error('Target user not found for admin mute');
  target.adminMuted = Boolean(payload.muted);
  if (target.adminMuted) target.micEnabled = false;
  broadcast(room, 'admin_mute/updated', {
    peer_id: target.id,
    user_id: target.userId,
    admin_muted: target.adminMuted,
    mic_enabled: target.micEnabled,
    room: roomSnapshot(room),
  });
}

function setRoomAdminStatus({ room, peer, payload }) {
  const target = findPeerByUserId(room, payload.target_user_id);
  if (!target) throw new Error('Target user not found for room admin update');
  const isRoomAdmin = payload.is_room_admin === true || payload.isRoomAdmin === true;
  target.isRoomAdmin = isRoomAdmin;
  broadcast(room, 'room_admin/updated', {
    room_id: room.id,
    actor_user_id: peer.userId,
    actor_name: peer.displayName,
    target_user_id: target.userId,
    target_name: target.displayName,
    is_room_admin: isRoomAdmin,
    role_label: isRoomAdmin ? 'Admin' : 'Member',
    room: roomSnapshot(room),
  });
}

function adminSeatLeave({ room, peer, payload }) {
  const target = findPeerByUserId(room, payload.target_user_id);
  if (!target) throw new Error('Target user not found for seat leave');
  clearPeerSeat(target);
  broadcastRoomSystemEvent(room, userRemovedEvent(peer, target));
  broadcast(room, 'seat/updated', {
    peer_id: target.id,
    user_id: target.userId,
    seat_index: null,
    mic_enabled: false,
    room: roomSnapshot(room),
  });
}

function setSeatLock({ room, payload, locked }) {
  const seatIndex = seatIndexFrom(payload.seat_index);
  if (seatIndex == null) throw new Error('seat_index is required');
  if (locked) {
    clearSeatOccupant(room, seatIndex);
    room.lockedSeatIndexes.add(seatIndex);
  } else {
    room.lockedSeatIndexes.delete(seatIndex);
  }
  broadcastSnapshot(room, 'seat/locked', { seat_index: seatIndex, locked });
}

function adminSeatLeaveLock({ room, peer, payload }) {
  const seatIndex = seatIndexFrom(payload.seat_index);
  if (seatIndex == null) throw new Error('seat_index is required');
  const target = findPeerByUserId(room, payload.target_user_id);
  if (target) {
    clearPeerSeat(target);
    broadcastRoomSystemEvent(room, userRemovedEvent(peer, target));
  }
  clearSeatOccupant(room, seatIndex);
  room.lockedSeatIndexes.add(seatIndex);
  broadcastSnapshot(room, 'seat/locked', {
    peer_id: target?.id,
    user_id: target?.userId,
    seat_index: seatIndex,
    locked: true,
  });
}

function adminBlockUser({ room, peer, payload }) {
  const target = findPeerByUserId(room, payload.target_user_id);
  if (!target) throw new Error('Target user not found');
  const durationMs = blockDurationMs(payload);
  const untilMs = durationMs === null ? null : Date.now() + durationMs;
  room.blockedUsers.set(target.userId, {
    untilMs,
    reason: payload.reason || 'Room access blocked.',
    blockedAt: Date.now(),
    actorPeerId: peer.id,
    actorUserId: peer.userId,
    actorName: peer.displayName,
  });
  clearPeerSeat(target);
  room.peers.delete(target.id);
  send(target.ws, `room/${roomBlockAction}ed`, {
    peer_id: target.id,
    user_id: target.userId,
    reason: payload.reason || 'Room access blocked.',
    kicked_until: untilMs === null ? null : new Date(untilMs).toISOString(),
    duration_ms: durationMs,
  });
  broadcastRoomSystemEvent(room, userRemovedEvent(peer, target));
  broadcast(room, 'room/peer_left', {
    peer_id: target.id,
    user_id: target.userId,
    display_name: target.displayName,
    room: roomSnapshot(room),
  });
  try { target.ws.close(); } catch (_error) {}
  clearEmptyRoom(room);
}

function removeRoomBlock({ ws, room, peer, payload }) {
  const targetUserId = String(payload.target_user_id || '').trim();
  if (!targetUserId) throw new Error('target_user_id is required');
  const removed = room.blockedUsers.delete(targetUserId);
  const body = { target_user_id: targetUserId, removed, room: roomSnapshot(room) };
  broadcast(room, `${roomBlockAction}_block/removed`, body);
  send(ws, `${roomBlockAction}_block/remove_result`, body);
}

function relayWebRtc({ ws, room, peer, type, payload }) {
  const target = room.peers.get(payload.target_peer_id);
  if (!target) {
    send(ws, 'error', { detail: 'Target peer not found for WebRTC signaling.' });
    return;
  }
  send(target.ws, type, { ...payload, from_peer_id: peer.id, from_user_id: peer.userId });
}

function roomChat({ room, peer, payload }) {
  broadcast(room, 'room/chat', {
    id: randomUUID(),
    peer_id: peer.id,
    user_id: peer.userId,
    display_name: peer.displayName,
    text: String(payload.text || '').slice(0, 500),
    created_at: new Date().toISOString(),
  });
}

function peerClosed(room, peer) {
  room.peers.delete(peer.id);
  broadcast(room, 'room/peer_left', {
    peer_id: peer.id,
    user_id: peer.userId,
    display_name: peer.displayName,
    room: roomSnapshot(room),
  });
  clearEmptyRoom(room);
}

module.exports = {
  send,
  joinRoom,
  leaveRoom,
  setRoomApplyMode,
  sendSeatInvite,
  requestSeatApplication,
  adminAssignSeat,
  takeSeat,
  leaveSeat,
  setMic,
  setAdminMute,
  setRoomAdminStatus,
  adminSeatLeave,
  setSeatLock,
  adminSeatLeaveLock,
  adminBlockUser,
  removeRoomBlock,
  relayWebRtc,
  roomChat,
  peerClosed,
};
