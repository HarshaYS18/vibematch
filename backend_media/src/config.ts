import 'dotenv/config';
import os from 'node:os';
import { z } from 'zod';

const envSchema = z.object({
  MEDIA_SERVICE_HOST: z.string().default('0.0.0.0'),
  MEDIA_SERVICE_PORT: z.coerce.number().int().min(1).max(65535).default(4100),
  MEDIA_NODE_ID: z.string().default(''),
  MEDIA_PUBLIC_URL: z.string().url().default('http://127.0.0.1:4100'),
  MEDIA_INTERNAL_TOKEN: z.string().min(16).default('change-this-media-internal-token'),
  MEDIA_HEARTBEAT_INTERVAL_MS: z.coerce.number().int().min(3000).default(10000),
  MEDIA_MAX_ROOMS: z.coerce.number().int().min(1).default(250),
  MEDIA_MAX_PEERS: z.coerce.number().int().min(1).default(5000),
  FASTAPI_BASE_URL: z.string().url().default('http://127.0.0.1:8000'),
  CORS_ORIGIN: z.string().default('*'),
  MEDIASOUP_LISTEN_IP: z.string().default('0.0.0.0'),
  MEDIASOUP_ANNOUNCED_IP: z.string().default(''),
  MEDIASOUP_MIN_PORT: z.coerce.number().int().min(1).max(65535).default(40000),
  MEDIASOUP_MAX_PORT: z.coerce.number().int().min(1).max(65535).default(49999),
  SOCKET_PING_TIMEOUT_MS: z.coerce.number().int().min(5000).default(20000),
  SOCKET_PING_INTERVAL_MS: z.coerce.number().int().min(5000).default(25000),
  VERIFY_TIMEOUT_MS: z.coerce.number().int().min(1000).default(6000),
});

const parsed = envSchema.parse(process.env);
const announcedIp = parsed.MEDIASOUP_ANNOUNCED_IP.trim() || detectLanIPv4();

export const config = {
  host: parsed.MEDIA_SERVICE_HOST,
  port: parsed.MEDIA_SERVICE_PORT,
  fastApiBaseUrl: parsed.FASTAPI_BASE_URL.replace(/\/$/, ''),
  corsOrigin: parsed.CORS_ORIGIN,
  verifyTimeoutMs: parsed.VERIFY_TIMEOUT_MS,
  registry: {
    nodeId: parsed.MEDIA_NODE_ID.trim() || os.hostname(),
    publicUrl: parsed.MEDIA_PUBLIC_URL.replace(/\/$/, ''),
    internalToken: parsed.MEDIA_INTERNAL_TOKEN,
    heartbeatIntervalMs: parsed.MEDIA_HEARTBEAT_INTERVAL_MS,
    maxRooms: parsed.MEDIA_MAX_ROOMS,
    maxPeers: parsed.MEDIA_MAX_PEERS,
  },
  socket: {
    pingTimeout: parsed.SOCKET_PING_TIMEOUT_MS,
    pingInterval: parsed.SOCKET_PING_INTERVAL_MS,
  },
  mediasoup: {
    listenIp: parsed.MEDIASOUP_LISTEN_IP,
    announcedIp,
    minPort: parsed.MEDIASOUP_MIN_PORT,
    maxPort: parsed.MEDIASOUP_MAX_PORT,
  },
};

function detectLanIPv4(): string {
  const fallbacks: string[] = [];
  for (const [name, interfaces] of Object.entries(os.networkInterfaces())) {
    for (const item of interfaces ?? []) {
      if (item.family !== 'IPv4' || item.internal) continue;
      if (isLikelyVirtualInterface(name)) {
        fallbacks.push(item.address);
        continue;
      }
      return item.address;
    }
  }
  return fallbacks[0] ?? '127.0.0.1';
}

function isLikelyVirtualInterface(name: string): boolean {
  const normalized = name.toLowerCase();
  return ['virtual', 'vmware', 'virtualbox', 'veth', 'docker', 'wsl', 'loopback', 'bluetooth'].some((part) =>
    normalized.includes(part),
  );
}
