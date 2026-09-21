import type { Server as HttpServer } from 'node:http';
import { Server } from 'socket.io';
import { config } from '../config.js';
import { startRoomMusic, stopRoomMusic } from '../media/musicSourceManager.js';
import { extractBearerToken, MediaAuthorizationError, verifyMediaAction } from '../auth/fastapiVerifier.js';
import type { Ack, MediaAction, MediaConsumer, MediaProducer, MediaWebRtcTransport, PeerState, RoomState } from '../types/mediaTypes.js';
import type { RoomManager } from '../mediasoup/roomManager.js';
import {
  connectTransportSchema,
  consumeSchema,
  consumerActionSchema,
  createTransportSchema,
  joinRoomSchema,
  leaveRoomSchema,
  produceSchema,
  producerActionSchema,
  roomMusicStartSchema,
  roomMusicStopSchema,
  socketAuthSchema,
} from './events.js';

export function createSocketServer(httpServer: HttpServer, roomManager: RoomManager): Server {
  const io = new Server(httpServer, {
    cors: { origin: config.corsOrigin, credentials: true },
    pingTimeout: config.socket.pingTimeout,
    pingInterval: config.socket.pingInterval,
  });

  io.use((socket, next) => {
    const parsed = socketAuthSchema.safeParse(socket.handshake.auth);
    if (!parsed.success) {
      mediaLog('auth.rejected', socket.id, { reason: 'missing_token' });
      next(new Error('Missing media socket auth token.'));
      return;
    }
    const bearerToken = extractBearerToken(parsed.data.token);
    if (!bearerToken) {
      mediaLog('auth.rejected', socket.id, { reason: 'invalid_token' });
      next(new Error('Invalid media socket auth token.'));
      return;
    }
    socket.data.auth = { bearerToken, deviceId: parsed.data.deviceId };
    mediaLog('auth.accepted', socket.id, { deviceIdPresent: Boolean(parsed.data.deviceId) });
    next();
  });

  io.on('connection', (socket) => {
    mediaLog('socket.connected', socket.id);
    socket.emit('connected', { socketId: socket.id });

    socket.on('joinRoom', async (payload: unknown, ack?: Ack) => {
      await safeAck('joinRoom', socket.id, ack, async () => {
        const input = joinRoomSchema.parse(payload);
        const auth = requireSocketAuth(socket.data.auth);
        mediaLog('joinRoom.received', socket.id, { roomPublicId: input.roomPublicId });
        const existingPeer = roomManager.getPeer(socket.id);
        if (existingPeer?.roomPublicId === input.roomPublicId) {
          await verifyPeerAction(existingPeer, 'join_room');
          const existingRoom = requireRoom(roomManager, existingPeer.roomPublicId);
          await socket.join(existingRoom.roomPublicId);
          mediaLog('joinRoom.reused', socket.id, { roomPublicId: existingRoom.roomPublicId });
          return joinRoomPayload(roomManager, existingRoom, existingPeer);
        }

        // Authorize the destination before disturbing an active room. This keeps
        // a valid current media session intact when the requested room is denied.
        const verified = await verifyMediaAction({
          bearerToken: auth.bearerToken,
          requestedAction: 'join_room',
          roomPublicId: input.roomPublicId,
          deviceId: input.deviceId ?? auth.deviceId,
        });

        if (existingPeer) {
          const existingRoom = roomManager.getPeerRoom(socket.id);
          if (existingRoom?.peers.size === 1) {
            await stopRoomMusic(existingRoom, io, 'room-switch');
          }
          const closed = roomManager.closePeer(socket.id);
          if (closed.roomPublicId) {
            await socket.leave(closed.roomPublicId);
            socket.to(closed.roomPublicId).emit('peerLeft', { socketId: socket.id, peerId: socket.id, producerIds: closed.producerIds });
          }
        }
        mediaLog('joinRoom.verified', socket.id, {
          roomPublicId: input.roomPublicId,
          publicUserId: verified.user.public_user_id,
          permissions: verified.permissions,
        });
        const room = await roomManager.getOrCreateRoom(input.roomPublicId);
        const peer = roomManager.ensurePeer({
          room,
          socketId: socket.id,
          user: verified.user,
          bearerToken: auth.bearerToken,
          deviceId: input.deviceId ?? auth.deviceId,
          permissions: verified.permissions,
          mediasoupContext: verified.mediasoup_context,
        });
        await socket.join(room.roomPublicId);
        socket.to(room.roomPublicId).emit('peerJoined', publicPeer(peer));
        return joinRoomPayload(roomManager, room, peer);
      });
    });

    socket.on('getRouterRtpCapabilities', async (_payload: unknown, ack?: Ack) => {
      await safeAck('getRouterRtpCapabilities', socket.id, ack, async () => {
        const peer = requirePeer(roomManager, socket.id);
        const room = requireRoom(roomManager, peer.roomPublicId);
        await verifyPeerAction(peer, 'consume_audio');
        mediaLog('rtpCapabilities.sent', socket.id, { roomPublicId: room.roomPublicId });
        return { rtpCapabilities: roomManager.getRtpCapabilities(room) };
      });
    });

    socket.on('createWebRtcTransport', async (payload: unknown, ack?: Ack) => {
      await safeAck('createWebRtcTransport', socket.id, ack, async () => {
        const input = createTransportSchema.parse(payload);
        const peer = requirePeer(roomManager, socket.id);
        mediaLog('transport.create.received', socket.id, { roomPublicId: peer.roomPublicId, direction: input.direction });
        await verifyPeerAction(peer, 'create_transport');
        const room = requireRoom(roomManager, peer.roomPublicId);
        const existingTransport = roomManager.getTransportByDirection(peer, input.direction);
        const transport = await roomManager.createWebRtcTransport({ room, peer, direction: input.direction });
        mediaLog(existingTransport ? 'transport.reused' : 'transport.create.ok', socket.id, { transportId: transport.id, direction: input.direction });
        return { params: serializeTransport(transport), ...serializeTransport(transport) };
      });
    });

    socket.on('connectWebRtcTransport', async (payload: unknown, ack?: Ack) => {
      await safeAck('connectWebRtcTransport', socket.id, ack, async () => {
        const input = connectTransportSchema.parse(payload);
        const peer = requirePeer(roomManager, socket.id);
        mediaLog('transport.connect.received', socket.id, { transportId: input.transportId });
        await verifyPeerAction(peer, 'connect_transport');
        const transport = requireTransport(peer, input.transportId);
        if (peer.connectedTransportIds.has(transport.id)) {
          mediaLog('transport.connect.reused', socket.id, { transportId: transport.id });
          return { transportId: transport.id };
        }
        await transport.connect({ dtlsParameters: input.dtlsParameters as never });
        peer.connectedTransportIds.add(transport.id);
        mediaLog('transport.connect.ok', socket.id, { transportId: transport.id });
        return { transportId: transport.id };
      });
    });

    socket.on('connectTransport', async (payload: unknown, ack?: Ack) => {
      await safeAck('connectTransport', socket.id, ack, async () => {
        const input = connectTransportSchema.parse(payload);
        const peer = requirePeer(roomManager, socket.id);
        mediaLog('transport.connectLegacy.received', socket.id, { transportId: input.transportId });
        await verifyPeerAction(peer, 'connect_transport');
        const transport = requireTransport(peer, input.transportId);
        if (peer.connectedTransportIds.has(transport.id)) {
          mediaLog('transport.connectLegacy.reused', socket.id, { transportId: transport.id });
          return { transportId: transport.id };
        }
        await transport.connect({ dtlsParameters: input.dtlsParameters as never });
        peer.connectedTransportIds.add(transport.id);
        mediaLog('transport.connectLegacy.ok', socket.id, { transportId: transport.id });
        return { transportId: transport.id };
      });
    });

    socket.on('produce', async (payload: unknown, ack?: Ack) => {
      await safeAck('produce', socket.id, ack, async () => {
        const input = produceSchema.parse(payload);
        const peer = requirePeer(roomManager, socket.id);
        mediaLog('produce.received', socket.id, { roomPublicId: peer.roomPublicId, transportId: input.transportId, kind: input.kind });
        await verifyPeerAction(peer, input.kind === 'video' ? 'produce_video' : 'produce_audio');
        closeExistingPeerProducers(roomManager, peer, socket, input.kind);
        const transport = requireTransport(peer, input.transportId);
        const producer = await transport.produce({
          kind: input.kind,
          rtpParameters: input.rtpParameters as never,
          appData: { ...input.appData, socketId: socket.id, publicUserId: peer.user.public_user_id },
        });
        peer.producers.set(producer.id, producer);
        producer.on('@close', () => peer.producers.delete(producer.id));
        const producerPayload = {
          producerId: producer.id,
          id: producer.id,
          kind: producer.kind,
          peerId: peer.socketId,
          peer: publicPeer(peer),
        };
        socket.to(peer.roomPublicId).emit('newProducer', producerPayload);
        mediaLog('produce.ok', socket.id, { producerId: producer.id, kind: producer.kind });
        return producerPayload;
      });
    });

    socket.on('consume', async (payload: unknown, ack?: Ack) => {
      await safeAck('consume', socket.id, ack, async () => {
        const input = consumeSchema.parse(payload);
        const peer = requirePeer(roomManager, socket.id);
        mediaLog('consume.received', socket.id, { roomPublicId: peer.roomPublicId, producerId: input.producerId });
        await verifyPeerAction(peer, 'consume_audio');
        const room = requireRoom(roomManager, peer.roomPublicId);
        const existingConsumerId = peer.consumerProducerIds.get(input.producerId);
        const existingConsumer = existingConsumerId ? peer.consumers.get(existingConsumerId) : undefined;
        if (existingConsumer) {
          mediaLog('consume.reused', socket.id, { consumerId: existingConsumer.id, producerId: input.producerId });
          return serializeConsumer(existingConsumer, input.producerId);
        }
        if (!room.router.canConsume({ producerId: input.producerId, rtpCapabilities: input.rtpCapabilities as never })) {
          throw new Error('Cannot consume this producer with provided RTP capabilities.');
        }
        const requestedTransport = input.transportId ? peer.transports.get(input.transportId) : undefined;
        const recvTransport = requestedTransport ?? [...peer.transports.values()].find((transport) => peer.transportDirections.get(transport.id) === 'recv');
        if (!recvTransport) throw new Error('No recv transport found for consumer.');
        const consumer = await recvTransport.consume({
          producerId: input.producerId,
          rtpCapabilities: input.rtpCapabilities as never,
          paused: true,
        });
        peer.consumers.set(consumer.id, consumer);
        peer.consumerProducerIds.set(input.producerId, consumer.id);
        consumer.on('@close', () => {
          peer.consumers.delete(consumer.id);
          peer.consumerProducerIds.delete(input.producerId);
        });
        mediaLog('consume.ok', socket.id, { consumerId: consumer.id, producerId: input.producerId });
        return serializeConsumer(consumer, input.producerId);
      });
    });

    socket.on('resumeConsumer', async (payload: unknown, ack?: Ack) => {
      await safeAck('resumeConsumer', socket.id, ack, async () => {
        const input = consumerActionSchema.parse(payload);
        const peer = requirePeer(roomManager, socket.id);
        const consumer = peer.consumers.get(input.consumerId);
        if (!consumer) throw new Error('Consumer not found.');
        await verifyPeerAction(peer, 'consume_audio');
        await consumer.resume();
        mediaLog('consumer.resume.ok', socket.id, { consumerId: consumer.id });
        return { consumerId: consumer.id };
      });
    });

    socket.on('pauseProducer', async (payload: unknown, ack?: Ack) => {
      await producerAction(roomManager, socket.id, payload, ack, 'pause_producer', async (producer) => producer.pause());
    });

    socket.on('resumeProducer', async (payload: unknown, ack?: Ack) => {
      await producerAction(roomManager, socket.id, payload, ack, 'resume_producer', async (producer) => producer.resume());
    });

    socket.on('closeProducer', async (payload: unknown, ack?: Ack) => {
      await safeAck('closeProducer', socket.id, ack, async () => {
        const input = producerActionSchema.parse(payload);
        const peer = requirePeer(roomManager, socket.id);
        await verifyPeerAction(peer, 'close_producer');
        if (!roomManager.closeProducer(peer, input.producerId)) throw new Error('Producer not found.');
        socket.to(peer.roomPublicId).emit('producerClosed', { producerId: input.producerId, peerId: peer.socketId });
        mediaLog('producer.close.ok', socket.id, { producerId: input.producerId });
        return { producerId: input.producerId };
      });
    });

    socket.on('startRoomMusic', async (payload: unknown, ack?: Ack) => {
      await safeAck('startRoomMusic', socket.id, ack, async () => {
        const input = roomMusicStartSchema.parse(payload);
        const peer = requirePeer(roomManager, socket.id);
        await verifyPeerAction(peer, 'start_room_music');
        const room = requireRoom(roomManager, peer.roomPublicId);
        const music = await startRoomMusic({
          room,
          io,
          controllerPeerId: peer.socketId,
          url: input.url,
          title: input.title,
          seekMs: input.seekMs,
        });
        mediaLog('roomMusic.start.ok', socket.id, {
          roomPublicId: peer.roomPublicId,
          producerId: music.producerId,
        });
        return { music };
      });
    });

    socket.on('stopRoomMusic', async (payload: unknown, ack?: Ack) => {
      await safeAck('stopRoomMusic', socket.id, ack, async () => {
        roomMusicStopSchema.parse(payload ?? {});
        const peer = requirePeer(roomManager, socket.id);
        await verifyPeerAction(peer, 'stop_room_music');
        const room = requireRoom(roomManager, peer.roomPublicId);
        await stopRoomMusic(room, io);
        mediaLog('roomMusic.stop.ok', socket.id, { roomPublicId: peer.roomPublicId });
        return { stopped: true };
      });
    });

    socket.on('leaveRoom', async (payload: unknown, ack?: Ack) => {
      await safeAck('leaveRoom', socket.id, ack, async () => {
        leaveRoomSchema.parse(payload ?? {});
        const leavingRoom = roomManager.getPeerRoom(socket.id);
        if (leavingRoom?.peers.size === 1) {
          await stopRoomMusic(leavingRoom, io, 'room-empty');
        }
        const closed = roomManager.closePeer(socket.id);
        if (closed.roomPublicId) {
          await socket.leave(closed.roomPublicId);
          socket.to(closed.roomPublicId).emit('peerLeft', { socketId: socket.id, peerId: socket.id, producerIds: closed.producerIds });
        }
        mediaLog('leaveRoom.ok', socket.id, closed);
        return { left: true };
      });
    });

    socket.on('disconnect', async (reason) => {
      await socketOperations.get(socket.id);
      const leavingRoom = roomManager.getPeerRoom(socket.id);
      if (leavingRoom?.peers.size === 1) {
        await stopRoomMusic(leavingRoom, io, 'room-empty');
      }
      const closed = roomManager.closePeer(socket.id);
      mediaLog('socket.disconnected', socket.id, { reason, ...closed });
      if (closed.roomPublicId) {
        socket.to(closed.roomPublicId).emit('peerLeft', { socketId: socket.id, peerId: socket.id, producerIds: closed.producerIds });
      }
    });
  });

  return io;
}

async function producerAction(
  roomManager: RoomManager,
  socketId: string,
  payload: unknown,
  ack: Ack | undefined,
  action: MediaAction,
  handler: (producer: MediaProducer) => Promise<void>,
): Promise<void> {
  await safeAck(action, socketId, ack, async () => {
    const input = producerActionSchema.parse(payload);
    const peer = requirePeer(roomManager, socketId);
    await verifyPeerAction(peer, action);
    const producer = peer.producers.get(input.producerId);
    if (!producer) throw new Error('Producer not found.');
    await handler(producer);
    mediaLog(`producer.${action}.ok`, socketId, { producerId: producer.id });
    return { producerId: producer.id };
  });
}

async function verifyPeerAction(peer: PeerState, requestedAction: MediaAction) {
  return verifyMediaAction({
    bearerToken: peer.bearerToken,
    requestedAction,
    roomPublicId: peer.roomPublicId,
    deviceId: peer.deviceId,
  });
}

function closeExistingPeerProducers(
  roomManager: RoomManager,
  peer: PeerState,
  socket: { to(room: string): { emit(event: string, payload: unknown): void } },
  kind: string,
): void {
  const existingProducerIds = [...peer.producers.keys()];
  for (const producerId of existingProducerIds) {
    const producer = peer.producers.get(producerId);
    if (producer?.kind !== kind) continue;
    producer?.close();
    peer.producers.delete(producerId);
    roomManager.closeConsumersForProducer(peer.roomPublicId, producerId);
    socket.to(peer.roomPublicId).emit('producerClosed', { producerId, peerId: peer.socketId });
    mediaLog('producer.duplicateClosed', peer.socketId, { producerId });
  }
}

function requireSocketAuth(raw: unknown): { bearerToken: string; deviceId?: string } {
  const auth = raw as { bearerToken?: unknown; deviceId?: unknown } | undefined;
  if (!auth || typeof auth.bearerToken !== 'string') throw new Error('Socket is not authenticated.');
  return {
    bearerToken: auth.bearerToken,
    deviceId: typeof auth.deviceId === 'string' ? auth.deviceId : undefined,
  };
}

function requirePeer(roomManager: RoomManager, socketId: string): PeerState {
  const peer = roomManager.getPeer(socketId);
  if (!peer) throw new Error('Peer has not joined a media room.');
  return peer;
}

function requireRoom(roomManager: RoomManager, roomPublicId: string) {
  const room = roomManager.getRoom(roomPublicId);
  if (!room) throw new Error('Media room not found.');
  return room;
}

function requireTransport(peer: PeerState, transportId: string): MediaWebRtcTransport {
  const transport = peer.transports.get(transportId);
  if (!transport) throw new Error('Transport not found.');
  return transport;
}

function serializeTransport(transport: MediaWebRtcTransport) {
  return {
    id: transport.id,
    iceParameters: transport.iceParameters,
    iceCandidates: transport.iceCandidates,
    dtlsParameters: transport.dtlsParameters,
    sctpParameters: transport.sctpParameters,
  };
}

function serializeConsumer(consumer: MediaConsumer, producerId: string) {
  const params = {
    id: consumer.id,
    consumerId: consumer.id,
    producerId,
    kind: consumer.kind,
    rtpParameters: consumer.rtpParameters,
  };
  return {
    params,
    ...params,
  };
}

function joinRoomPayload(roomManager: RoomManager, room: RoomState, peer: PeerState) {
  const roomPayload = {
    seats: [],
    producers: roomManager.serializeProducers?.(room) ?? [],
  };
  return {
    roomPublicId: room.roomPublicId,
    rtpCapabilities: roomManager.getRtpCapabilities(room),
    room: roomPayload,
    peer: publicPeer(peer),
    permissions: peer.permissions,
    mediasoupContext: peer.mediasoupContext,
  };
}

function publicPeer(peer: PeerState) {
  return {
    socketId: peer.socketId,
    peerId: peer.socketId,
    publicUserId: peer.user.public_user_id,
    displayName: peer.user.display_name,
    avatarUrl: peer.user.avatar_url,
    roles: peer.user.roles,
    primaryRole: peer.user.primary_role,
  };
}

const socketOperations = new Map<string, Promise<void>>();

async function safeAck<T>(eventName: string, socketId: string, ack: Ack<T> | undefined, handler: () => Promise<T>): Promise<void> {
  const previous = socketOperations.get(socketId) ?? Promise.resolve();
  const operation = previous.then(() => executeAck(eventName, socketId, ack, handler));
  socketOperations.set(socketId, operation);
  try {
    await operation;
  } finally {
    if (socketOperations.get(socketId) === operation) socketOperations.delete(socketId);
  }
}

async function executeAck<T>(eventName: string, socketId: string, ack: Ack<T> | undefined, handler: () => Promise<T>): Promise<void> {
  try {
    const data = await handler();
    ack?.(ackPayload(data));
  } catch (error) {
    const message = error instanceof MediaAuthorizationError
      ? error.reason ?? error.message
      : error instanceof Error
        ? error.message
        : 'Unknown media signaling error.';
    mediaLog(`${eventName}.failed`, socketId, { error: message });
    ack?.({ ok: false, error: message });
  }
}

function ackPayload<T>(data: T): { ok: true; data: T; [key: string]: unknown } {
  if (data && typeof data === 'object' && !Array.isArray(data)) {
    return { ok: true, ...(data as Record<string, unknown>), data };
  }
  return { ok: true, data };
}

function mediaLog(event: string, socketId: string, data: Record<string, unknown> = {}): void {
  const payload = Object.keys(data).length ? ` ${JSON.stringify(data)}` : '';
  console.log(`[media] ${event} socket=${socketId}${payload}`);
}
