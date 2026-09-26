import { config } from '../config.js';
import type {
  MediaConsumer,
  MediaProducer,
  MediaWebRtcTransport,
  PeerState,
  RoomState,
  TransportDirection,
  VerifiedMediaUser,
} from '../types/mediaTypes.js';
import type { WorkerManager } from './workerManager.js';

export function canonicalPeerId(roomPublicId: string, publicUserId: number): string {
  return `${roomPublicId}_user_${publicUserId}`.replace(/[^a-zA-Z0-9_-]/g, '_');
}

export class RoomManager {
  private readonly rooms = new Map<string, RoomState>();
  private readonly pendingRooms = new Map<string, Promise<RoomState>>();

  constructor(private readonly workerManager: WorkerManager) {}

  async getOrCreateRoom(roomPublicId: string): Promise<RoomState> {
    const existing = this.rooms.get(roomPublicId);
    if (existing) {
      existing.lastActiveAt = Date.now();
      return existing;
    }

    const pending = this.pendingRooms.get(roomPublicId);
    if (pending) return pending;
    if (this.rooms.size + this.pendingRooms.size >= config.registry.maxRooms) {
      throw new Error('Media node room capacity reached.');
    }

    const creation = this.createRoom(roomPublicId);
    this.pendingRooms.set(roomPublicId, creation);
    try {
      return await creation;
    } finally {
      this.pendingRooms.delete(roomPublicId);
    }
  }

  private async createRoom(roomPublicId: string): Promise<RoomState> {
    const router = await this.workerManager.createRouter();
    const room: RoomState = {
      roomPublicId,
      router,
      peers: new Map<string, PeerState>(),
      serverProducers: new Map(),
      createdAt: Date.now(),
      lastActiveAt: Date.now(),
    };
    this.rooms.set(roomPublicId, room);
    return room;
  }

  getRoom(roomPublicId: string): RoomState | undefined {
    return this.rooms.get(roomPublicId);
  }

  ensurePeer(params: {
    room: RoomState;
    socketId: string;
    user: VerifiedMediaUser;
    bearerToken: string;
    deviceId?: string;
    permissions?: string[];
    mediasoupContext?: Record<string, unknown>;
  }): PeerState {
    const existing = params.room.peers.get(params.socketId);
    if (existing) return existing;

    if (this.getStats().peerCount >= config.registry.maxPeers) {
      throw new Error('Media node peer capacity reached.');
    }

    const peer: PeerState = {
      socketId: params.socketId,
      peerId: canonicalPeerId(params.room.roomPublicId, params.user.public_user_id),
      user: params.user,
      bearerToken: params.bearerToken,
      deviceId: params.deviceId,
      roomPublicId: params.room.roomPublicId,
      joinedAt: Date.now(),
      permissions: params.permissions ?? [],
      mediasoupContext: params.mediasoupContext ?? {},
      transports: new Map<string, MediaWebRtcTransport>(),
      transportDirections: new Map<string, TransportDirection>(),
      connectedTransportIds: new Set<string>(),
      producers: new Map<string, MediaProducer>(),
      consumers: new Map<string, MediaConsumer>(),
      consumerProducerIds: new Map<string, string>(),
    };
    params.room.peers.set(params.socketId, peer);
    params.room.lastActiveAt = Date.now();
    return peer;
  }

  getPeer(socketId: string): PeerState | undefined {
    for (const room of this.rooms.values()) {
      const peer = room.peers.get(socketId);
      if (peer) return peer;
    }
    return undefined;
  }

  getPeerRoom(socketId: string): RoomState | undefined {
    for (const room of this.rooms.values()) {
      if (room.peers.has(socketId)) return room;
    }
    return undefined;
  }

  getStats(): { roomCount: number; peerCount: number; hotRoomCount: number; maxRoomPeers: number; roomIds: string[] } {
    let peerCount = 0;
    let hotRoomCount = 0;
    let maxRoomPeers = 0;
    for (const room of this.rooms.values()) {
      const peers = room.peers.size;
      peerCount += peers;
      if (peers >= config.registry.hotRoomPeers) hotRoomCount += 1;
      if (peers > maxRoomPeers) maxRoomPeers = peers;
    }
    return {
      roomCount: this.rooms.size,
      peerCount,
      hotRoomCount,
      maxRoomPeers,
      roomIds: [...this.rooms.keys()],
    };
  }

  getRtpCapabilities(room: RoomState): unknown {
    return room.router.rtpCapabilities;
  }

  serializeProducers(room: RoomState): Array<Record<string, unknown>> {
    const producers: Array<Record<string, unknown>> = [];
    for (const peer of room.peers.values()) {
      for (const producer of peer.producers.values()) {
        producers.push({
          producerId: producer.id,
          id: producer.id,
          peerId: peer.peerId,
          kind: producer.kind,
          publicUserId: peer.user.public_user_id,
        });
      }
    }
    for (const serverProducer of room.serverProducers.values()) {
      producers.push({
        producerId: serverProducer.producer.id,
        id: serverProducer.producer.id,
        peerId: serverProducer.peerId,
        kind: serverProducer.producer.kind,
        appData: serverProducer.appData,
      });
    }
    return producers;
  }

  getTransportByDirection(
    peer: PeerState,
    direction: TransportDirection,
  ): MediaWebRtcTransport | undefined {
    return [...peer.transports.values()].find(
      (transport) => peer.transportDirections.get(transport.id) === direction,
    );
  }

  async createWebRtcTransport(params: {
    room: RoomState;
    peer: PeerState;
    direction: TransportDirection;
  }): Promise<MediaWebRtcTransport> {
    const existing = this.getTransportByDirection(params.peer, params.direction);
    if (existing) {
      params.room.lastActiveAt = Date.now();
      return existing;
    }

    const transport = await params.room.router.createWebRtcTransport({
      listenIps: [
        {
          ip: config.mediasoup.listenIp,
          announcedIp: config.mediasoup.announcedIp,
        },
      ],
      enableUdp: true,
      enableTcp: true,
      preferUdp: true,
      initialAvailableOutgoingBitrate: config.qos.initialAvailableOutgoingBitrate,
    });

    params.peer.transports.set(transport.id, transport);
    params.peer.transportDirections.set(transport.id, params.direction);
    params.room.lastActiveAt = Date.now();

    transport.on('dtlsstatechange', (state: string) => {
      if (state === 'closed') transport.close();
    });
    transport.on('@close', () => {
      params.peer.transports.delete(transport.id);
      params.peer.transportDirections.delete(transport.id);
      params.peer.connectedTransportIds.delete(transport.id);
    });

    return transport;
  }

  closePeer(socketId: string): { roomPublicId?: string; producerIds: string[] } {
    const room = this.getPeerRoom(socketId);
    const peer = this.getPeer(socketId);
    if (!room || !peer) return { producerIds: [] };

    const producerIds = [...peer.producers.keys()];
    for (const consumer of peer.consumers.values()) consumer.close();
    for (const producer of peer.producers.values()) producer.close();
    for (const transport of peer.transports.values()) transport.close();
    room.peers.delete(socketId);
    room.lastActiveAt = Date.now();

    if (room.peers.size === 0) {
      for (const serverProducer of room.serverProducers.values()) {
        serverProducer.producer.close();
      }
      room.serverProducers.clear();
      room.router.close();
      this.rooms.delete(room.roomPublicId);
    }

    return { roomPublicId: room.roomPublicId, producerIds };
  }

  closeProducer(peer: PeerState, producerId: string): boolean {
    const producer = peer.producers.get(producerId);
    if (!producer) return false;
    producer.close();
    peer.producers.delete(producerId);
    this.closeConsumersForProducer(peer.roomPublicId, producerId);
    return true;
  }

  closeConsumersForProducer(roomPublicId: string, producerId: string): string[] {
    const room = this.rooms.get(roomPublicId);
    if (!room) return [];

    const closedConsumerIds: string[] = [];
    for (const peer of room.peers.values()) {
      const consumerId = peer.consumerProducerIds.get(producerId);
      if (!consumerId) continue;
      const consumer = peer.consumers.get(consumerId);
      if (consumer) {
        consumer.close();
        closedConsumerIds.push(consumerId);
      }
      peer.consumers.delete(consumerId);
      peer.consumerProducerIds.delete(producerId);
    }
    room.lastActiveAt = Date.now();
    return closedConsumerIds;
  }
}
