const { randomUUID } = require('crypto');
const {
  roomBlockAction,
  getOrCreateRoom,
  roomSnapshot,
  createPeer,
  createDefaultMusicState,
  createDefaultCricketState,
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

function canControlRoom(peer) {
  return peer?.isHost === true || peer?.isRoomAdmin === true;
}

function cleanText(value, fallback = '') {
  const text = String(value ?? '').trim();
  return text || fallback;
}

function numberFrom(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function samePeer(room, peer) {
  return room.peers.get(peer.id) === peer;
}

function findSeatOccupant(room, seatIndex) {
  for (const peer of room.peers.values()) {
    if (peer.seatIndex === seatIndex) return peer;
  }
  return null;
}

function replaceExistingPeer(room, peer) {
  for (const existing of Array.from(room.peers.values())) {
    if (existing.id !== peer.id && existing.userId !== peer.userId) continue;

    if (existing.seatIndex != null && peer.seatIndex == null) peer.seatIndex = existing.seatIndex;
    peer.micEnabled = existing.micEnabled === true;
    peer.adminMuted = existing.adminMuted === true;

    room.peers.delete(existing.id);
    if (existing.ws !== peer.ws) {
      try { existing.ws.close(); } catch (_error) {}
    }
  }
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
  replaceExistingPeer(room, peer);
  room.peers.set(peer.id, peer);
  setSession(room, peer);

  send(ws, 'room/joined', { peer_id: peer.id, room: roomSnapshot(room) });
  if (room.musicState?.active === true) {
    send(ws, 'room_music/state', { room_id: room.id, music_state: room.musicState });
  }
  if (room.cricketState?.active === true) {
    send(ws, 'room_cricket/state', {
      room_id: room.id,
      active: true,
      cricket_state: room.cricketState,
      setup: room.cricketState.setup,
      background_theme_id: room.cricketState.backgroundThemeId || 'cricket_floodlight_arena',
      actor_user_id: room.cricketState.controllerUserId || '',
      actor_name: room.cricketState.controllerName || 'Cricket Mode',
      room: roomSnapshot(room),
    });
  }
  broadcast(room, 'room/peer_joined', {
    peer_id: peer.id,
    user_id: peer.userId,
    display_name: peer.displayName,
    room: roomSnapshot(room),
  }, peer.id);
  broadcastRoomSystemEvent(room, userEnteredEvent(peer), peer.id);
}

function updateProfile({ room, peer, payload }) {
  if (!samePeer(room, peer)) return;

  peer.displayName = cleanText(payload.display_name ?? payload.displayName, peer.displayName || 'Vibe User');
  if (Object.prototype.hasOwnProperty.call(payload, 'avatar_url') || Object.prototype.hasOwnProperty.call(payload, 'avatarUrl')) {
    peer.avatarUrl = cleanText(payload.avatar_url ?? payload.avatarUrl, '');
  }
  peer.vipLevel = numberFrom(payload.vip_level ?? payload.vipLevel, peer.vipLevel);
  peer.svipLevel = numberFrom(payload.svip_level ?? payload.svipLevel, peer.svipLevel);
  peer.sendingLevel = numberFrom(payload.sending_level ?? payload.sendingLevel, peer.sendingLevel);
  peer.receivingLevel = numberFrom(payload.receiving_level ?? payload.receivingLevel, peer.receivingLevel);

  if (Object.prototype.hasOwnProperty.call(payload, 'is_host') || Object.prototype.hasOwnProperty.call(payload, 'isHost')) {
    peer.isHost = payload.is_host === true || payload.isHost === true;
  }
  if (Object.prototype.hasOwnProperty.call(payload, 'is_room_admin') || Object.prototype.hasOwnProperty.call(payload, 'isRoomAdmin')) {
    peer.isRoomAdmin = payload.is_room_admin === true || payload.isRoomAdmin === true || peer.isHost === true;
  }
  peer.roleLabel = cleanText(
    payload.role_label ?? payload.roleLabel,
    peer.isHost ? 'Channel Host' : peer.isRoomAdmin ? 'Admin' : peer.roleLabel || 'Member',
  );

  broadcastSnapshot(room, 'profile/updated', {
    peer_id: peer.id,
    user_id: peer.userId,
    display_name: peer.displayName,
    avatar_url: peer.avatarUrl,
    vip_level: peer.vipLevel,
    svip_level: peer.svipLevel,
    sending_level: peer.sendingLevel,
    receiving_level: peer.receivingLevel,
    is_host: peer.isHost === true,
    is_room_admin: peer.isRoomAdmin === true || peer.isHost === true,
    role_label: peer.roleLabel,
  });
}

function leaveRoom({ ws, room, peer, clearSession }) {
  if (!samePeer(room, peer)) {
    send(ws, 'room/left', { peer_id: peer.id });
    clearSession();
    return;
  }
  room.peers.delete(peer.id);
  if (room.musicState?.controllerPeerId === peer.id || room.musicState?.producerPeerId === peer.id) {
    room.musicState = createDefaultMusicState();
    broadcast(room, 'room_music/state', { room_id: room.id, music_state: room.musicState });
  }
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
    room_images_enabled: room.roomImagesEnabled !== false,
    guest_messages_enabled: room.guestMessagesEnabled !== false,
    room: roomSnapshot(room),
    created_at: new Date().toISOString(),
  });
}

function setRoomImages({ room, peer, payload }) {
  if (!canControlRoom(peer)) throw new Error('Only host/admin can change image messages.');
  room.roomImagesEnabled = payload.enabled === true || payload.room_images_enabled === true || payload.roomImagesEnabled === true;
  broadcast(room, 'room_settings/updated', {
    id: randomUUID(),
    room_id: room.id,
    actor_user_id: peer.userId,
    actor_name: peer.displayName,
    apply_only_mode_enabled: room.applyOnlyModeEnabled === true,
    room_images_enabled: room.roomImagesEnabled === true,
    guest_messages_enabled: room.guestMessagesEnabled !== false,
    room: roomSnapshot(room),
    created_at: new Date().toISOString(),
  });
}

function setGuestMessages({ room, peer, payload }) {
  if (!canControlRoom(peer)) throw new Error('Only host/admin can change guest messages.');
  room.guestMessagesEnabled = payload.enabled === true || payload.guest_messages_enabled === true || payload.guestMessagesEnabled === true;
  broadcast(room, 'room_settings/updated', {
    id: randomUUID(),
    room_id: room.id,
    actor_user_id: peer.userId,
    actor_name: peer.displayName,
    apply_only_mode_enabled: room.applyOnlyModeEnabled === true,
    room_images_enabled: room.roomImagesEnabled !== false,
    guest_messages_enabled: room.guestMessagesEnabled === true,
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
    if (peer.seatIndex === seatIndex && peer.id !== target.id && peer.userId !== target.userId) {
      throw new Error(`Seat ${seatIndex + 1} is already occupied`);
    }
    if (peer.seatIndex === seatIndex && peer.userId === target.userId) clearPeerSeat(peer);
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
  const occupant = findSeatOccupant(room, seatIndex);
  if (occupant && occupant.id !== peer.id) {
    if (occupant.userId !== peer.userId) {
      send(ws, 'error', { detail: `Seat ${seatIndex + 1} is already occupied.` });
      return;
    }
    clearPeerSeat(occupant);
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
  target.roleLabel = isRoomAdmin ? 'Admin' : 'Member';
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

function roomSystemMessage({ room, peer, payload }) {
  const message = String(payload.message || '').trim();
  if (!message) return;

  broadcast(room, 'room/system_event', {
    id: randomUUID(),
    event_type: 'room_system_message',
    room_id: room.id,
    actor_user_id: peer.userId,
    actor_name: peer.displayName,
    target_user_id: '',
    target_name: '',
    message,
    created_at: new Date().toISOString(),
  });
}

function roomChatClear({ room, peer }) {
  broadcast(room, 'room/system_event', {
    id: randomUUID(),
    event_type: 'chat_cleared',
    room_id: room.id,
    actor_user_id: peer.userId,
    actor_name: peer.displayName,
    target_user_id: '',
    target_name: '',
    message: `Chat cleared for everyone by ${peer.displayName}`,
    created_at: new Date().toISOString(),
  });
}

function roomChat({ room, peer, payload }) {
  if (room.guestMessagesEnabled === false && !canControlRoom(peer)) return;
  broadcast(room, 'room/chat', {
    id: randomUUID(),
    peer_id: peer.id,
    user_id: peer.userId,
    display_name: peer.displayName,
    text: String(payload.text || '').slice(0, 500),
    created_at: new Date().toISOString(),
  });
}

function roomMusicControl({ room, peer, payload }) {
  if (!canControlRoom(peer)) throw new Error('Only host/admin can control room music.');
  const action = String(payload.action || 'state').trim();
  const positionMs = Math.max(0, Number(payload.position_ms ?? payload.positionMs ?? 0) || 0);
  const durationMs = Math.max(0, Number(payload.duration_ms ?? payload.durationMs ?? 0) || 0);
  const trackTitle = String(payload.track_title ?? payload.trackTitle ?? '').slice(0, 180);
  const trackId = String(payload.track_id ?? payload.trackId ?? '').slice(0, 120);
  const producerId = String(payload.producer_id ?? payload.producerId ?? '').slice(0, 160);

  room.musicState = {
    ...(room.musicState || createDefaultMusicState()),
    active: action !== 'stop',
    action,
    controllerPeerId: peer.id,
    controllerUserId: peer.userId,
    controllerName: peer.displayName,
    trackId,
    trackTitle,
    positionMs,
    durationMs,
    producerPeerId: peer.id,
    producerId,
    mediaTag: 'room-music-audio',
    updatedAt: new Date().toISOString(),
  };

  broadcast(room, 'room_music/control', {
    id: randomUUID(),
    room_id: room.id,
    music_state: room.musicState,
    room: roomSnapshot(room),
  });
}

function roomMusicProducerStarted({ room, peer, payload }) {
  if (!canControlRoom(peer)) throw new Error('Only host/admin can publish room music.');
  room.musicState = {
    ...(room.musicState || createDefaultMusicState()),
    active: true,
    action: 'producer_started',
    controllerPeerId: peer.id,
    controllerUserId: peer.userId,
    controllerName: peer.displayName,
    trackId: String(payload.track_id ?? payload.trackId ?? '').slice(0, 120),
    trackTitle: String(payload.track_title ?? payload.trackTitle ?? '').slice(0, 180),
    positionMs: Math.max(0, Number(payload.position_ms ?? payload.positionMs ?? 0) || 0),
    durationMs: Math.max(0, Number(payload.duration_ms ?? payload.durationMs ?? 0) || 0),
    producerPeerId: peer.id,
    producerId: String(payload.producer_id ?? payload.producerId ?? '').slice(0, 160),
    mediaTag: 'room-music-audio',
    updatedAt: new Date().toISOString(),
  };

  broadcast(room, 'room_music/producer_started', {
    id: randomUUID(),
    room_id: room.id,
    music_state: room.musicState,
    room: roomSnapshot(room),
  });
}

function roomMusicStop({ room, peer }) {
  if (!canControlRoom(peer)) throw new Error('Only host/admin can stop room music.');
  room.musicState = {
    ...createDefaultMusicState(),
    action: 'stop',
    controllerPeerId: peer.id,
    controllerUserId: peer.userId,
    controllerName: peer.displayName,
    updatedAt: new Date().toISOString(),
  };
  broadcast(room, 'room_music/control', {
    id: randomUUID(),
    room_id: room.id,
    music_state: room.musicState,
    room: roomSnapshot(room),
  });
}

function roomCricketStart({ room, peer, payload }) {
  if (!canControlRoom(peer)) throw new Error('Only host/admin can start Cricket Mode.');

  const setup = payload.setup || payload;
  const backgroundThemeId = String(
    payload.background_theme_id ||
    payload.backgroundThemeId ||
    setup.background_theme_id ||
    setup.backgroundThemeId ||
    'cricket_floodlight_arena'
  );

  room.cricketState = {
    active: true,
    action: 'start',
    controllerPeerId: peer.id,
    controllerUserId: peer.userId,
    controllerName: peer.displayName,
    setup,
    backgroundThemeId,
    updatedAt: new Date().toISOString(),
  };

  broadcast(room, 'room_cricket/state', {
    id: randomUUID(),
    room_id: room.id,
    active: true,
    cricket_state: room.cricketState,
    setup,
    background_theme_id: backgroundThemeId,
    actor_user_id: peer.userId,
    actor_name: peer.displayName,
    room: roomSnapshot(room),
  });
}

function roomCricketEnd({ room, peer, payload = {} }) {
  if (!canControlRoom(peer)) throw new Error('Only host/admin can end Cricket Mode.');

  room.cricketState = {
    ...createDefaultCricketState(),
    action: 'stop',
    controllerPeerId: peer.id,
    controllerUserId: peer.userId,
    controllerName: peer.displayName,
    updatedAt: new Date().toISOString(),
  };

  broadcast(room, 'room_cricket/state', {
    id: randomUUID(),
    room_id: room.id,
    active: false,
    cricket_state: room.cricketState,
    setup: null,
    background_theme_id: payload.background_theme_id || payload.backgroundThemeId || 'default_pearl',
    actor_user_id: peer.userId,
    actor_name: peer.displayName,
    room: roomSnapshot(room),
  });
}

function peerClosed(room, peer) {
  if (!samePeer(room, peer)) return;
  room.peers.delete(peer.id);
  if (room.musicState?.controllerPeerId === peer.id || room.musicState?.producerPeerId === peer.id) {
    room.musicState = createDefaultMusicState();
    broadcast(room, 'room_music/state', { room_id: room.id, music_state: room.musicState });
  }
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
  updateProfile,
  leaveRoom,
  setRoomApplyMode,
  setRoomImages,
  setGuestMessages,
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
  roomSystemMessage,
  roomChatClear,
  roomChat,
  roomMusicControl,
  roomMusicProducerStarted,
  roomMusicStop,
  roomCricketStart,
  roomCricketEnd,
  peerClosed,
};
