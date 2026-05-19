export type MediaAction =
  | 'join_room'
  | 'create_transport'
  | 'connect_transport'
  | 'produce_audio'
  | 'consume_audio'
  | 'pause_producer'
  | 'resume_producer'
  | 'close_producer'
  | 'leave_room';

export type TransportDirection = 'send' | 'recv';

export interface MediaProducer {
  id: string;
  kind: string;
  pause(): Promise<void>;
  resume(): Promise<void>;
  close(): void;
  on(event: '@close', handler: () => void): void;
}

export interface MediaConsumer {
  id: string;
  kind: string;
  rtpParameters: unknown;
  resume(): Promise<void>;
  close(): void;
  on(event: '@close', handler: () => void): void;
}

export interface MediaWebRtcTransport {
  id: string;
  iceParameters: unknown;
  iceCandidates: unknown;
  dtlsParameters: unknown;
  sctpParameters?: unknown;
  connect(options: { dtlsParameters: never }): Promise<void>;
  produce(options: {
    kind: 'audio';
    rtpParameters: never;
    appData?: Record<string, unknown>;
  }): Promise<MediaProducer>;
  consume(options: {
    producerId: string;
    rtpCapabilities: never;
    paused?: boolean;
  }): Promise<MediaConsumer>;
  close(): void;
  on(event: 'dtlsstatechange', handler: (state: string) => void): void;
  on(event: '@close', handler: () => void): void;
}

export interface MediaRouter {
  rtpCapabilities: unknown;
  createWebRtcTransport(options: Record<string, unknown>): Promise<MediaWebRtcTransport>;
  canConsume(options: { producerId: string; rtpCapabilities: never }): boolean;
  close(): void;
}

export interface MediaWorker {
  createRouter(options: Record<string, unknown>): Promise<MediaRouter>;
  close(): void;
  on(event: 'died', handler: () => void): void;
}

export interface VerifiedMediaUser {
  user_id: number;
  public_user_id: number;
  username?: string | null;
  display_name?: string | null;
  avatar_url?: string | null;
  roles: string[];
  primary_role: string;
  is_active: boolean;
  is_banned: boolean;
}

export interface MediaVerifyResponse {
  allowed: boolean;
  reason?: string | null;
  user: VerifiedMediaUser;
  room_public_id?: string | null;
  requested_action: MediaAction | string;
  permissions: string[];
  mediasoup_context: Record<string, unknown>;
}

export interface SocketAuthContext {
  bearerToken: string;
  deviceId?: string;
  user?: VerifiedMediaUser;
}

export interface PeerState {
  socketId: string;
  user: VerifiedMediaUser;
  bearerToken: string;
  deviceId?: string;
  roomPublicId: string;
  joinedAt: number;
  transports: Map<string, MediaWebRtcTransport>;
  transportDirections: Map<string, TransportDirection>;
  producers: Map<string, MediaProducer>;
  consumers: Map<string, MediaConsumer>;
}

export interface RoomState {
  roomPublicId: string;
  router: MediaRouter;
  peers: Map<string, PeerState>;
  createdAt: number;
  lastActiveAt: number;
}

export interface CallbackResponse<T = unknown> {
  ok: boolean;
  data?: T;
  error?: string;
}

export type Ack<T = unknown> = (response: CallbackResponse<T>) => void;
