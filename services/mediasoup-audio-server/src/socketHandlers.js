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
  setSeatProducer,
  setSelfMuted,
  setAdminMuted,
} = require('./roomManager');

async function createWebRtcTransport(router) {
  const transport = await router.createWebRtcTransport(config.mediasoup.webRtcTransport);

  transport.on('dtlsstatechange', (dtlsState) => {
    if (dtlsState === 'closed') {
      transport.close();
    }
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
  return Array.from(room.peers.values())
    .filter((peer) => peer.id !== requestingPeerId)
    .flatMap((peer) =>
      Array.from(peer.producers.values()).map((producer) => ({
        producerId: producer.id,
        peerId: peer.id,
        kind: producer.kind,
        seatNo: peer.seatNo,
      })),
    );
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
    if (paused) {
      producer.pause();
    } else {
      producer.resume();
    }
  }
}

function requireJoinedPeer(roomId, peerId, expectedRoomId, expectedPeerId) {
  if (String(roomId) !== String(expectedRoomId) || String(peerId) !== String(expectedPeerId)) {
    throw new Error('peer session mismatch');
  }
}

function registerSocketHandlers(io) {
  io.on('connection', (socket) => {
    console.log(`[socket] connected socket=${socket.id}`);

    let joinedRoomId = null;
    let joinedPeerId = null;

    socket.on('joinRoom', async ({ roomId, peerId, audioToken }, callback) => {
      try {
        if (!roomId || !peerId) {
          throw new Error('roomId and peerId are required');
        }

        validateAudioToken({ audioToken, roomId, peerId });

        joinedRoomId = String(roomId);
        joinedPeerId = String(peerId);

        const room = await getOrCreateRoom(joinedRoomId);
        let peer = room.peers.get(joinedPeerId);

        if (!peer) {
          peer = createPeer(room, joinedPeerId, socket.id);
        } else {
          peer.socketId = socket.id;
        }

        socket.join(joinedRoomId);

        callback({
          ok: true,
          rtpCapabilities: room.router.rtpCapabilities,
          iceServers: config.iceServers,
          room: {
            id: room.id,
            maxSpeakersPerRoom: config.maxSpeakersPerRoom,
            maxRoomPeers: config.maxRoomPeers,
            seats: getSeatSnapshot(room),
            producers: getProducerSnapshot(room, joinedPeerId),
          },
        });

        socket.to(joinedRoomId).emit('peerJoined', { peerId: joinedPeerId });
        console.log(`[joinRoom] room=${joinedRoomId} peer=${joinedPeerId}`);
      } catch (error) {
        console.error('[joinRoom] error', error);
        callback({ ok: false, error: error.message });
      }
    });

    socket.on('takeSeat', ({ roomId, peerId, seatNo }, callback) => {
      try {
        requireJoinedPeer(roomId, peerId, joinedRoomId, joinedPeerId);
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const seat = takeSeat(room, String(peerId), Number(seatNo));
        const payload = { seat, seats: getSeatSnapshot(room) };

        io.to(roomId).emit('seatsUpdated', payload);
        callback({ ok: true, ...payload });
      } catch (error) {
        console.error('[takeSeat] error', error);
        callback({ ok: false, error: error.message });
      }
    });

    socket.on('leaveSeat', ({ roomId, peerId }, callback) => {
      try {
        requireJoinedPeer(roomId, peerId, joinedRoomId, joinedPeerId);
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const peer = room.peers.get(String(peerId));
        if (peer) {
          closePeerProducers(room, peer, io);
        }

        const seat = leaveSeat(room, String(peerId));
        const payload = { seat, seats: getSeatSnapshot(room) };

        io.to(roomId).emit('seatsUpdated', payload);
        callback({ ok: true, ...payload });
      } catch (error) {
        console.error('[leaveSeat] error', error);
        callback({ ok: false, error: error.message });
      }
    });

    socket.on('createWebRtcTransport', async ({ roomId, peerId, direction }, callback) => {
      try {
        requireJoinedPeer(roomId, peerId, joinedRoomId, joinedPeerId);
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const peer = room.peers.get(String(peerId));
        if (!peer) throw new Error('peer not found');

        if (direction === 'send' && !peer.seatNo) {
          throw new Error('only seated peers may create a send transport');
        }

        const { transport, params } = await createWebRtcTransport(room.router);
        peer.transports.set(transport.id, transport);

        callback({ ok: true, params });
      } catch (error) {
        console.error('[createWebRtcTransport] error', error);
        callback({ ok: false, error: error.message });
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
        callback({ ok: true });
      } catch (error) {
        console.error('[connectTransport] error', error);
        callback({ ok: false, error: error.message });
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

        const payload = {
          producerId: producer.id,
          peerId: peer.id,
          kind: producer.kind,
          seatNo: peer.seatNo,
        };

        socket.to(roomId).emit('newProducer', payload);
        io.to(roomId).emit('seatsUpdated', { seats: getSeatSnapshot(room) });

        callback({ ok: true, ...payload });
        console.log(`[produce] room=${roomId} peer=${peer.id} producer=${producer.id}`);
      } catch (error) {
        console.error('[produce] error', error);
        callback({ ok: false, error: error.message });
      }
    });

    socket.on('consume', async ({ roomId, peerId, producerId, transportId, rtpCapabilities }, callback) => {
      try {
        requireJoinedPeer(roomId, peerId, joinedRoomId, joinedPeerId);
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const peer = room.peers.get(String(peerId));
        if (!peer) throw new Error('peer not found');

        if (!room.router.canConsume({ producerId, rtpCapabilities })) {
          throw new Error('client cannot consume this producer');
        }

        const transport = peer.transports.get(transportId);
        if (!transport) throw new Error('transport not found');

        const consumer = await transport.consume({
          producerId,
          rtpCapabilities,
          paused: false,
        });

        peer.consumers.set(consumer.id, consumer);

        consumer.on('transportclose', () => {
          peer.consumers.delete(consumer.id);
        });

        consumer.on('producerclose', () => {
          peer.consumers.delete(consumer.id);
          socket.emit('producerClosed', { producerId });
        });

        callback({
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
        callback({ ok: false, error: error.message });
      }
    });

    socket.on('setSelfMuted', ({ roomId, peerId, muted }, callback) => {
      try {
        requireJoinedPeer(roomId, peerId, joinedRoomId, joinedPeerId);
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const peer = room.peers.get(String(peerId));
        if (peer) {
          pausePeerProducers(peer, Boolean(muted));
        }

        const seat = setSelfMuted(room, String(peerId), Boolean(muted));
        const payload = { seat, seats: getSeatSnapshot(room) };

        io.to(roomId).emit('seatsUpdated', payload);
        callback({ ok: true, ...payload });
      } catch (error) {
        console.error('[setSelfMuted] error', error);
        callback({ ok: false, error: error.message });
      }
    });

    socket.on('setAdminMuted', ({ roomId, targetPeerId, muted }, callback) => {
      try {
        if (String(roomId) !== String(joinedRoomId)) {
          throw new Error('room session mismatch');
        }
        const room = getRoom(roomId);
        if (!room) throw new Error('room not found');

        const peer = room.peers.get(String(targetPeerId));
        if (peer) {
          pausePeerProducers(peer, Boolean(muted));
        }

        const seat = setAdminMuted(room, String(targetPeerId), Boolean(muted));
        const payload = { seat, seats: getSeatSnapshot(room) };

        io.to(roomId).emit('seatsUpdated', payload);
        callback({ ok: true, ...payload });
      } catch (error) {
        console.error('[setAdminMuted] error', error);
        callback({ ok: false, error: error.message });
      }
    });

    socket.on('disconnect', () => {
      console.log(`[socket] disconnected socket=${socket.id}`);

      if (joinedRoomId && joinedPeerId) {
        const room = removePeer(joinedRoomId, joinedPeerId);
        socket.to(joinedRoomId).emit('peerLeft', { peerId: joinedPeerId });

        if (room) {
          socket.to(joinedRoomId).emit('seatsUpdated', { seats: getSeatSnapshot(room) });
        }
      }
    });
  });
}

module.exports = {
  registerSocketHandlers,
};
