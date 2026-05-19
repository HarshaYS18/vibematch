import type { Server as HttpServer } from 'node:http';
import { Server } from 'socket.io';
import type { Producer, WebRtcTransport } from 'mediasoup';
import { config } from '../config.js';
import { extractBearerToken, MediaAuthorizationError, verifyMediaAction } from '../auth/fastapiVerifier.js';
import type { Ack, MediaAction, PeerState } from '../types/mediaTypes.js';
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
      next(new Error('Missing media socket auth token.'));
      return;
    }
    const bearerToken = extractBearerToken(parsed.data.token);
    if (!bearerToken) {
      next(new Error('Invalid media socket auth token.'));
      return;
    }
    socket.data.auth = { bearerToken, deviceId: parsed.data.deviceId };
    next();
  });

  io.on('connection', (socket) => {
    socket.emit('connected', { socketId: socket.id });

    socket.on('joinRoom', async (payload: unknown, ack?: Ack) => {
      await safeAck(ack, async () => {
        const input = joinRoomSchema.parse(payload);
        const auth = requireSocketAuth(socket.data.auth);
        const verified = await verifyMediaAction({
          bearerToken: auth.bearerToken,
          requestedAction: 'join_room',
          roomPublicId: input.roomPublicId,
          deviceId: input.deviceId ?? auth.deviceId,
        });
        const room = await roomManager.getOrCreateRoom(input.roomPublicId);
        const peer = roomManager.ensurePeer({
          room,
          socketId: socket.id,
          user: verified.user,
          bearerToken: auth.bearerToken,
          deviceId: input.deviceId ?? auth.deviceId,
        });
        await socket.join(room.roomPublicId);
        socket.to(room.roomPublicId).emit('peerJoined', publicPeer(peer));
        return {
          roomPublicId: room.roomPublicId,
          rtpCapabilities: roomManager.getRtpCapabilities(room),
          peer: publicPeer(peer),
          permissions: verified.permissions,
          mediasoupContext: verified.mediasoup_context,
        };
      });
    });

    socket.on('getRouterRtpCapabilities', async (_payload: unknown, ack?: Ack) => {
      await safeAck(ack, async () => {
        const peer = requirePeer(roomManager, socket.id);
        const room = requireRoom(roomManager, peer.roomPublicId);
        return { rtpCapabilities: roomManager.getRtpCapabilities(room) };
      });
    });

    socket.on('createWebRtcTransport', async (payload: unknown, ack?: Ack) => {
      await safeAck(ack, async () => {
        const input = createTransportSchema.parse(payload);
        const peer = requirePeer(roomManager, socket.id);
        await verifyPeerAction(peer, 'create_transport');
        const room = requireRoom(roomManager, peer.roomPublicId);
        const transport = await roomManager.createWebRtcTransport({ room, peer, direction: input.direction });
        return serializeTransport(transport);
      });
    });

    socket.on('connectWebRtcTransport', async (payload: unknown, ack?: Ack) => {
      await safeAck(ack, async () => {
        const input = connectTransportSchema.parse(payload);
        const peer = requirePeer(roomManager, socket.id);
        await verifyPeerAction(peer, 'connect_transport');
        const transport = requireTransport(peer, input.transportId);
        await transport.connect({ dtlsParameters: input.dtlsParameters as never });
        return { transportId: transport.id };
      });
    });

    socket.on('produce', async (payload: unknown, ack?: Ack) => {
      await safeAck(ack, async () => {
        const input = produceSchema.parse(payload);
        const peer = requirePeer(roomManager, socket.id);
        await verifyPeerAction(peer, 'produce_audio');
        const transport = requireTransport(peer, input.transportId);
        const producer = await transport.produce({
          kind: input.kind,
          rtpParameters: input.rtpParameters as never,
          appData: { ...input.appData, socketId: socket.id, publicUserId: peer.user.public_user_id },
        });
        peer.producers.set(producer.id, producer);
        producer.on('@close', () => peer.producers.delete(producer.id));
        socket.to(peer.roomPublicId).emit('newProducer', {
          producerId: producer.id,
          kind: producer.kind,
          peer: publicPeer(peer),
        });
        return { producerId: producer.id };
      });
    });

    socket.on('consume', async (payload: unknown, ack?: Ack) => {
      await safeAck(ack, async () => {
        const input = consumeSchema.parse(payload);
        const peer = requirePeer(roomManager, socket.id);
        await verifyPeerAction(peer, 'consume_audio');
        const room = requireRoom(roomManager, peer.roomPublicId);
        if (!room.router.canConsume({ producerId: input.producerId, rtpCapabilities: input.rtpCapabilities as never })) {
          throw new Error('Cannot consume this producer with provided RTP capabilities.');
        }
        const recvTransport = [...peer.transports.values()].find((transport) => peer.transportDirections.get(transport.id) === 'recv');
        if (!recvTransport) throw new Error('No recv transport found for consumer.');
        const consumer = await recvTransport.consume({
          producerId: input.producerId,
          rtpCapabilities: input.rtpCapabilities as never,
          paused: true,
        });
        peer.consumers.set(consumer.id, consumer);
        consumer.on('@close', () => peer.consumers.delete(consumer.id));
        return {
          consumerId: consumer.id,
          producerId: input.producerId,
          kind: consumer.kind,
          rtpParameters: consumer.rtpParameters,
        };
      });
    });

    socket.on('resumeConsumer', async (payload: unknown, ack?: Ack) => {
      await safeAck(ack, async () => {
        const input = consumerActionSchema.parse(payload);
        const peer = requirePeer(roomManager, socket.id);
        const consumer = peer.consumers.get(input.consumerId);
        if (!consumer) throw new Error('Consumer not found.');
        await consumer.resume();
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
      await safeAck(ack, async () => {
        const input = producerActionSchema.parse(payload);
        const peer = requirePeer(roomManager, socket.id);
        await verifyPeerAction(peer, 'close_producer');
        if (!roomManager.closeProducer(peer, input.producerId)) throw new Error('Producer not found.');
        socket.to(peer.roomPublicId).emit('producerClosed', { producerId: input.producerId });
        return { producerId: input.producerId };
      });
    });

    socket.on('leaveRoom', async (payload: unknown, ack?: Ack) => {
      await safeAck(ack, async () => {
        leaveRoomSchema.parse(payload ?? {});
        const closed = roomManager.closePeer(socket.id);
        if (closed.roomPublicId) {
          await socket.leave(closed.roomPublicId);
          socket.to(closed.roomPublicId).emit('peerLeft', { socketId: socket.id, producerIds: closed.producerIds });
        }
        return { left: true };
      });
    });

    socket.on('disconnect', () => {
      const closed = roomManager.closePeer(socket.id);
      if (closed.roomPublicId) {
        socket.to(closed.roomPublicId).emit('peerLeft', { socketId: socket.id, producerIds: closed.producerIds });
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
  handler: (producer: Producer) => Promise<void>,
): Promise<void> {
  await safeAck(ack, async () => {
    const input = producerActionSchema.parse(payload);
    const peer = requirePeer(roomManager, socketId);
    await verifyPeerAction(peer, action);
    const producer = peer.producers.get(input.producerId);
    if (!producer) throw new Error('Producer not found.');
    await handler(producer);
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

function requireTransport(peer: PeerState, transportId: string): WebRtcTransport {
  const transport = peer.transports.get(transportId);
  if (!transport) throw new Error('Transport not found.');
  return transport;
}

function serializeTransport(transport: WebRtcTransport) {
  return {
    id: transport.id,
    iceParameters: transport.iceParameters,
    iceCandidates: transport.iceCandidates,
    dtlsParameters: transport.dtlsParameters,
    sctpParameters: transport.sctpParameters,
  };
}

function publicPeer(peer: PeerState) {
  return {
    socketId: peer.socketId,
    publicUserId: peer.user.public_user_id,
    displayName: peer.user.display_name,
    avatarUrl: peer.user.avatar_url,
    roles: peer.user.roles,
    primaryRole: peer.user.primary_role,
  };
}

async function safeAck<T>(ack: Ack<T> | undefined, handler: () => Promise<T>): Promise<void> {
  try {
    const data = await handler();
    ack?.({ ok: true, data });
  } catch (error) {
    const message = error instanceof MediaAuthorizationError
      ? error.reason ?? error.message
      : error instanceof Error
        ? error.message
        : 'Unknown media signaling error.';
    ack?.({ ok: false, error: message });
  }
}
