import type { Consumer, Producer, Router, WebRtcTransport } from 'mediasoup/node/lib/types';

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
  transports: Map<string, WebRtcTransport>;
  transportDirections: Map<string, TransportDirection>;
  producers: Map<string, Producer>;
  consumers: Map<string, Consumer>;
}

export interface RoomState {
  roomPublicId: string;
  router: Router;
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
