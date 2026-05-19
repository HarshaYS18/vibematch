import type { Consumer, Producer, RtpCapabilities, WebRtcTransport } from 'mediasoup';
import { config } from '../config.js';
import type { PeerState, RoomState, TransportDirection, VerifiedMediaUser } from '../types/mediaTypes.js';
import type { WorkerManager } from './workerManager.js';

export class RoomManager {
  private readonly rooms = new Map<string, RoomState>();

  constructor(private readonly workerManager: WorkerManager) {}

  async getOrCreateRoom(roomPublicId: string): Promise<RoomState> {
    const existing = this.rooms.get(roomPublicId);
    if (existing) {
      existing.lastActiveAt = Date.now();
      return existing;
    }

    const router = await this.workerManager.createRouter();
    const room: RoomState = {
      roomPublicId,
      router,
      peers: new Map<string, PeerState>(),
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
  }): PeerState {
    const existing = params.room.peers.get(params.socketId);
    if (existing) return existing;

    const peer: PeerState = {
      socketId: params.socketId,
      user: params.user,
      bearerToken: params.bearerToken,
      deviceId: params.deviceId,
      roomPublicId: params.room.roomPublicId,
      joinedAt: Date.now(),
      transports: new Map<string, WebRtcTransport>(),
      transportDirections: new Map<string, TransportDirection>(),
      producers: new Map<string, Producer>(),
      consumers: new Map<string, Consumer>(),
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

  getRtpCapabilities(room: RoomState): RtpCapabilities {
    return room.router.rtpCapabilities;
  }

  async createWebRtcTransport(params: {
    room: RoomState;
    peer: PeerState;
    direction: TransportDirection;
  }): Promise<WebRtcTransport> {
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
      initialAvailableOutgoingBitrate: 800000,
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
    return true;
  }
}
