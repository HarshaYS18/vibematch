const config = require('./config');
const { validateAudioToken } = require('./auth');
const {
  getOrCreateRoom,
  getRoom,
  createPeer,
  removePeer,
  getSeatSnapshot,
  takeSeat,
  leaveSeat,
  lockSeat,
  unlockSeat,
  forceLeaveSeat,
  forceLeaveAndLockSeat,
  setSeatProducer,
  setSelfMuted,
  setAdminMuted,
} = require('./roomManager');
const {
  SERVER_MUSIC_PEER_ID,
  ensureRoomMusicState,
  startRoomMusic,
  stopRoomMusic,
} = require('./musicSourceManager');

async function createWebRtcTransport(router) {
  const transport = await router.createWebRtcTransport(config.mediasoup.webRtcTransport);

  transport.on('dtlsstatechange', (dtlsState) => {
    if (dtlsState === 'closed') transport.close();
  });

  return {
    transport,
    params: {
      id: transport.id,
      iceParameters: transport.iceParameters,
      iceCandidates: transport.iceCandidates,
      dtlsParameters: transport.dtlsParameters,
    },
  };
}

function getProducerSnapshot(room, requestingPeerId) {
  const peerProducers = Array.from(room.peers.values())
    .filter((peer) => peer.id !== requestingPeerId)
    .flatMap((peer) =>
      Array.from(peer.producers.values()).map((producer) => ({
        producerId: producer.id,
        peerId: peer.id,
        kind: producer.kind,
        seatNo: peer.seatNo,
        appData: producer.appData || {},
      })),
    );

  const music = ensureRoomMusicState(room);
  if (music.producer && !music.producer.closed && music.state.active) {
    peerProducers.push({
      producerId: music.producer.id,
      peerId: SERVER_MUSIC_PEER_ID,
      kind: music.producer.kind,
      seatNo: null,
      appData: music.producer.appData || {},
    });
  }

  return peerProducers;
}

function closePeerProducers(room, peer, io) {
  const closedProducerIds = [];

  for (const producer of peer.producers.values()) {
    closedProducerIds.push(producer.id);
    producer.close();
  }

  peer.producers.clear();

  for (const producerId of closedProducerIds) {
    io.to(room.id).emit('producerClosed', { producerId, peerId: peer.id });
  }

  return closedProducerIds;
}

function pausePeerProducers(peer, paused) {
  for (const producer of peer.producers.values()) {
    if (paused) producer.pause();
    else producer.resume();
  }
}

function requireJoinedPeer(roomId, peerId, expectedRoomId, expectedPeerId) {
  if (String(roomId) !== String(expectedRoomId) || String(peerId) !== String(expectedPeerId)) {
    throw new Error('peer session mismatch');
  }
}

function safeCallback(callback, payload) {
  if (typeof callback === 'function') callback(payload);
}

function emitSeatsUpdated(io, roomId, room, extra = {}) {
  const seats = getSeatSnapshot(room);
  const payload = { ...extra, seats };
  io.to(roomId).emit('seatsUpdated', payload);
  console.log(`[seatsUpdated] room=${roomId} occupied=${seats.filter((seat) => seat.peerId).length}/${seats.length}`);
  return payload;
}

async function stopMusicIfControlledByPeer(room, io, peerId, reason) {
  if (!room) return;
  const music = ensureRoomMusicState(room);
  if (music.state.active && music.state.controllerPeerId === String(peerId)) {
    await stopRoomMusic(room, io, reason);
  }
}

function registerSocketHandlers(io) {
  io.on('connection', (socket) => {
    console.log(`[socket] connected socket=${socket.id}`);

    let joinedRoomId = null;
    let joinedPeerId = null;

    socket.on('joinRoom', async ({ roomId, peerId, audioToken }, callback) => {
      try {
        if (!roomId || !peerId) throw new Error('roomId and peerId are required');

        validateAudioToken({ audioToken, roomId, peerId });

        joinedRoomId = String(roomId);
        joinedPeerId = String(peerId);

        const room = await getOrCreateRoom(joinedRoomId);
        ensureRoomMusicState(room);
        let peer = room.peers.get(joinedPeerId);

        if (!peer) peer = createPeer(room, joinedPeerId, socket.id);
        else peer.socketId = socket.id;

        socket.join(joinedRoomId);

        safeCallback(callback, {
          ok: true,
          rtpCapabilities: room.router.rtpCapabilities,
          iceServers: config.iceServers,
          room: {
            id: room.id,
            maxSpeakersPerRoom: config.maxSpeakersPerRoom,
            maxRoomPeers: config.maxRoomPeers,
            seats: getSeatSnapshot(room),
            producers: getProducerSnapshot(room, joinedPeerId),
            music: ensureRoomMusicState(room).state,
          },
        });

        socket.to(joinedRoomId).emit('peerJoined', { peerId: joinedPeerId });
        console.log(`[joinRoom] room=${joinedRoomId} peer=${joinedPeerId} socket=${socket.id}`);
      } catch (error) {
        console.error('[joinRoom] error', error);
        safeCallback(callback, { ok: false, error: error.message });
      }
    });

    socket.on('takeSeat', ({ roomId, peerId, seatNo }, callback) => {
      try {
        requireJoinedPeer(roomId, peerId, joinedRoomId, joinedPeerId);
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const seat = takeSeat(room, String(peerId), Number(seatNo));
        const payload = emitSeatsUpdated(io, roomId, room, { seat });
        console.log(`[takeSeat] room=${roomId} peer=${peerId} seatNo=${seatNo}`);
        safeCallback(callback, { ok: true, ...payload });
      } catch (error) {
        console.error('[takeSeat] error', error);
        safeCallback(callback, { ok: false, error: error.message });
      }
    });

    socket.on('leaveSeat', ({ roomId, peerId }, callback) => {
      try {
        requireJoinedPeer(roomId, peerId, joinedRoomId, joinedPeerId);
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const peer = room.peers.get(String(peerId));
        if (peer) closePeerProducers(room, peer, io);

        const seat = leaveSeat(room, String(peerId));
        const payload = emitSeatsUpdated(io, roomId, room, { seat });
        console.log(`[leaveSeat] room=${roomId} peer=${peerId}`);
        safeCallback(callback, { ok: true, ...payload });
      } catch (error) {
        console.error('[leaveSeat] error', error);
        safeCallback(callback, { ok: false, error: error.message });
      }
    });

    socket.on('adminSeatLeave', ({ roomId, targetPeerId }, callback) => {
      try {
        if (String(roomId) !== String(joinedRoomId)) throw new Error('room session mismatch');
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const peer = room.peers.get(String(targetPeerId));
        if (peer) closePeerProducers(room, peer, io);

        const seat = forceLeaveSeat(room, String(targetPeerId));
        const payload = emitSeatsUpdated(io, roomId, room, { seat, targetPeerId: String(targetPeerId) });
        console.log(`[adminSeatLeave] room=${roomId} targetPeer=${targetPeerId}`);
        safeCallback(callback, { ok: true, ...payload });
      } catch (error) {
        console.error('[adminSeatLeave] error', error);
        safeCallback(callback, { ok: false, error: error.message });
      }
    });

    socket.on('adminSeatLock', ({ roomId, seatNo }, callback) => {
      try {
        if (String(roomId) !== String(joinedRoomId)) throw new Error('room session mismatch');
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const seat = lockSeat(room, Number(seatNo));
        const payload = emitSeatsUpdated(io, roomId, room, { seat });
        console.log(`[adminSeatLock] room=${roomId} seatNo=${seatNo}`);
        safeCallback(callback, { ok: true, ...payload });
      } catch (error) {
        console.error('[adminSeatLock] error', error);
        safeCallback(callback, { ok: false, error: error.message });
      }
    });

    socket.on('adminSeatUnlock', ({ roomId, seatNo }, callback) => {
      try {
        if (String(roomId) !== String(joinedRoomId)) throw new Error('room session mismatch');
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const seat = unlockSeat(room, Number(seatNo));
        const payload = emitSeatsUpdated(io, roomId, room, { seat });
        console.log(`[adminSeatUnlock] room=${roomId} seatNo=${seatNo}`);
        safeCallback(callback, { ok: true, ...payload });
      } catch (error) {
        console.error('[adminSeatUnlock] error', error);
        safeCallback(callback, { ok: false, error: error.message });
      }
    });

    socket.on('adminSeatLeaveLock', ({ roomId, seatNo, targetPeerId }, callback) => {
      try {
        if (String(roomId) !== String(joinedRoomId)) throw new Error('room session mismatch');
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const peer = room.peers.get(String(targetPeerId));
        if (peer) closePeerProducers(room, peer, io);

        const seat = forceLeaveAndLockSeat(room, Number(seatNo), String(targetPeerId));
        const payload = emitSeatsUpdated(io, roomId, room, { seat, targetPeerId: String(targetPeerId) });
        console.log(`[adminSeatLeaveLock] room=${roomId} seatNo=${seatNo} targetPeer=${targetPeerId}`);
        safeCallback(callback, { ok: true, ...payload });
      } catch (error) {
        console.error('[adminSeatLeaveLock] error', error);
        safeCallback(callback, { ok: false, error: error.message });
      }
    });

    socket.on('adminKick', ({ roomId, targetPeerId, reason }, callback) => {
      try {
        if (String(roomId) !== String(joinedRoomId)) throw new Error('room session mismatch');
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const targetPeerIdString = String(targetPeerId);
        const peer = room.peers.get(targetPeerIdString);
        if (peer) closePeerProducers(room, peer, io);

        const updatedRoom = removePeer(roomId, targetPeerIdString);
        io.to(roomId).emit('peerKicked', { peerId: targetPeerIdString, reason: reason || 'Removed by room admin' });
        if (updatedRoom) emitSeatsUpdated(io, roomId, updatedRoom, { targetPeerId: targetPeerIdString });
        console.log(`[adminKick] room=${roomId} targetPeer=${targetPeerIdString}`);
        safeCallback(callback, { ok: true, targetPeerId: targetPeerIdString });
      } catch (error) {
        console.error('[adminKick] error', error);
        safeCallback(callback, { ok: false, error: error.message });
      }
    });

    socket.on('createWebRtcTransport', async ({ roomId, peerId, direction }, callback) => {
      try {
        requireJoinedPeer(roomId, peerId, joinedRoomId, joinedPeerId);
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const peer = room.peers.get(String(peerId));
        if (!peer) throw new Error('peer not found');
        if (direction === 'send' && !peer.seatNo) throw new Error('only seated peers may create a send transport');

        const { transport, params } = await createWebRtcTransport(room.router);
        peer.transports.set(transport.id, transport);
        console.log(`[createWebRtcTransport] room=${roomId} peer=${peerId} direction=${direction} transport=${transport.id}`);
        safeCallback(callback, { ok: true, params });
      } catch (error) {
        console.error('[createWebRtcTransport] error', error);
        safeCallback(callback, { ok: false, error: error.message });
      }
    });

    socket.on('connectTransport', async ({ roomId, peerId, transportId, dtlsParameters }, callback) => {
      try {
        requireJoinedPeer(roomId, peerId, joinedRoomId, joinedPeerId);
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const peer = room.peers.get(String(peerId));
        if (!peer) throw new Error('peer not found');

        const transport = peer.transports.get(transportId);
        if (!transport) throw new Error('transport not found');

        await transport.connect({ dtlsParameters });
        console.log(`[connectTransport] room=${roomId} peer=${peerId} transport=${transportId}`);
        safeCallback(callback, { ok: true });
      } catch (error) {
        console.error('[connectTransport] error', error);
        safeCallback(callback, { ok: false, error: error.message });
      }
    });

    socket.on('produce', async ({ roomId, peerId, transportId, kind, rtpParameters }, callback) => {
      try {
        requireJoinedPeer(roomId, peerId, joinedRoomId, joinedPeerId);
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const peer = room.peers.get(String(peerId));
        if (!peer) throw new Error('peer not found');
        if (!peer.seatNo) throw new Error('peer must take one of the 17 seats before producing audio');
        if (kind !== 'audio') throw new Error('this POC is audio-only');

        const transport = peer.transports.get(transportId);
        if (!transport) throw new Error('transport not found');

        closePeerProducers(room, peer, io);

        const producer = await transport.produce({ kind, rtpParameters });
        peer.producers.set(producer.id, producer);
        setSeatProducer(room, peer.id, producer.id);

        producer.on('transportclose', () => {
          peer.producers.delete(producer.id);
          io.to(roomId).emit('producerClosed', { producerId: producer.id, peerId: peer.id });
        });

        producer.on('close', () => {
          peer.producers.delete(producer.id);
        });

        const payload = { producerId: producer.id, peerId: peer.id, kind: producer.kind, seatNo: peer.seatNo, appData: producer.appData || {} };
        socket.to(roomId).emit('newProducer', payload);
        io.to(roomId).emit('seatsUpdated', { seats: getSeatSnapshot(room) });
        safeCallback(callback, { ok: true, ...payload });
        console.log(`[produce] room=${roomId} peer=${peer.id} producer=${producer.id}`);
      } catch (error) {
        console.error('[produce] error', error);
        safeCallback(callback, { ok: false, error: error.message });
      }
    });

    socket.on('consume', async ({ roomId, peerId, producerId, transportId, rtpCapabilities }, callback) => {
      try {
        requireJoinedPeer(roomId, peerId, joinedRoomId, joinedPeerId);
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const peer = room.peers.get(String(peerId));
        if (!peer) throw new Error('peer not found');

        if (!room.router.canConsume({ producerId, rtpCapabilities })) throw new Error('client cannot consume this producer');

        const transport = peer.transports.get(transportId);
        if (!transport) throw new Error('transport not found');

        const consumer = await transport.consume({ producerId, rtpCapabilities, paused: false });
        peer.consumers.set(consumer.id, consumer);

        consumer.on('transportclose', () => peer.consumers.delete(consumer.id));
        consumer.on('producerclose', () => {
          peer.consumers.delete(consumer.id);
          socket.emit('producerClosed', { producerId });
        });

        console.log(`[consume] room=${roomId} peer=${peerId} producer=${producerId} consumer=${consumer.id}`);
        safeCallback(callback, {
          ok: true,
          params: {
            id: consumer.id,
            producerId,
            kind: consumer.kind,
            rtpParameters: consumer.rtpParameters,
          },
        });
      } catch (error) {
        console.error('[consume] error', error);
        safeCallback(callback, { ok: false, error: error.message });
      }
    });

    socket.on('resumeConsumer', async ({ roomId, peerId, consumerId }, callback) => {
      try {
        requireJoinedPeer(roomId, peerId, joinedRoomId, joinedPeerId);
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const peer = room.peers.get(String(peerId));
        if (!peer) throw new Error('peer not found');

        const consumer = peer.consumers.get(String(consumerId));
        if (!consumer) throw new Error('consumer not found');

        await consumer.resume();
        console.log(`[resumeConsumer] room=${roomId} peer=${peerId} consumer=${consumer.id} producer=${consumer.producerId}`);
        safeCallback(callback, { ok: true });
      } catch (error) {
        console.error('[resumeConsumer] error', error);
        safeCallback(callback, { ok: false, error: error.message });
      }
    });

    socket.on('startRoomMusic', async ({ roomId, peerId, url, title, seekMs }, callback) => {
      try {
        requireJoinedPeer(roomId, peerId, joinedRoomId, joinedPeerId);
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        console.log('[startRoomMusic] request', { roomId, peerId, title, url });
        const music = await startRoomMusic({
          room,
          io,
          controllerPeerId: String(peerId),
          url,
          title,
          seekMs,
        });

        console.log('[startRoomMusic] ok', {
          roomId,
          producerId: music.producerId,
          title: music.title,
        });
        safeCallback(callback, { ok: true, music });
      } catch (error) {
        console.error('[startRoomMusic] error', error);
        safeCallback(callback, { ok: false, error: error.message });
      }
    });

    socket.on('stopRoomMusic', async ({ roomId, peerId }, callback) => {
      try {
        requireJoinedPeer(roomId, peerId, joinedRoomId, joinedPeerId);
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        await stopRoomMusic(room, io, 'stop-requested');
        console.log('[stopRoomMusic] ok', { roomId, peerId });
        safeCallback(callback, { ok: true });
      } catch (error) {
        console.error('[stopRoomMusic] error', error);
        safeCallback(callback, { ok: false, error: error.message });
      }
    });

    socket.on('setSelfMuted', ({ roomId, peerId, muted }, callback) => {
      try {
        requireJoinedPeer(roomId, peerId, joinedRoomId, joinedPeerId);
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const peer = room.peers.get(String(peerId));
        if (peer) pausePeerProducers(peer, Boolean(muted));

        const seat = setSelfMuted(room, String(peerId), Boolean(muted));
        const payload = emitSeatsUpdated(io, roomId, room, { seat });
        console.log(`[setSelfMuted] room=${roomId} peer=${peerId} muted=${Boolean(muted)}`);
        safeCallback(callback, { ok: true, ...payload });
      } catch (error) {
        console.error('[setSelfMuted] error', error);
        safeCallback(callback, { ok: false, error: error.message });
      }
    });

    socket.on('setAdminMuted', ({ roomId, targetPeerId, muted }, callback) => {
      try {
        if (String(roomId) !== String(joinedRoomId)) throw new Error('room session mismatch');
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const peer = room.peers.get(String(targetPeerId));
        if (peer) pausePeerProducers(peer, Boolean(muted));

        const seat = setAdminMuted(room, String(targetPeerId), Boolean(muted));
        const payload = emitSeatsUpdated(io, roomId, room, { seat });
        console.log(`[setAdminMuted] room=${roomId} targetPeer=${targetPeerId} muted=${Boolean(muted)}`);
        safeCallback(callback, { ok: true, ...payload });
      } catch (error) {
        console.error('[setAdminMuted] error', error);
        safeCallback(callback, { ok: false, error: error.message });
      }
    });

    socket.on('disconnect', () => {
      console.log(`[socket] disconnected socket=${socket.id}`);

      if (!joinedRoomId || !joinedPeerId) return;

      const existingRoom = getRoom(joinedRoomId);
      const existingPeer = existingRoom?.peers.get(String(joinedPeerId));

      if (existingPeer && existingPeer.socketId !== socket.id) {
        console.log(`[socket] stale disconnect ignored socket=${socket.id} activeSocket=${existingPeer.socketId} room=${joinedRoomId} peer=${joinedPeerId}`);
        return;
      }

      stopMusicIfControlledByPeer(existingRoom, io, joinedPeerId, 'controller-disconnect').catch((error) => {
        console.error('[disconnect] stop controlled room music failed', error);
      });

      const room = removePeer(joinedRoomId, joinedPeerId);
      socket.to(joinedRoomId).emit('peerLeft', { peerId: joinedPeerId });

      if (room) socket.to(joinedRoomId).emit('seatsUpdated', { seats: getSeatSnapshot(room) });
    });
  });
}

module.exports = {
  registerSocketHandlers,
};
