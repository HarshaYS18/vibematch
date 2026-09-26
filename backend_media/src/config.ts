import 'dotenv/config';
import os from 'node:os';
import { z } from 'zod';

const envSchema = z.object({
  APP_ENV: z.string().default('development'),
  OTEL_TRACES_ENABLED: z.enum(['true', 'false']).default('false'),
  OTEL_EXPORTER_OTLP_TRACES_ENDPOINT: z.string().url().default('http://127.0.0.1:4318/v1/traces'),
  OTEL_EXPORT_TIMEOUT_MS: z.coerce.number().int().min(100).default(3000),
  MEDIA_SERVICE_HOST: z.string().default('0.0.0.0'),
  MEDIA_SERVICE_PORT: z.coerce.number().int().min(1).max(65535).default(4100),
  MEDIA_NODE_ID: z.string().default(''),
  MEDIA_PUBLIC_URL: z.string().url().default('http://127.0.0.1:4100'),
  MEDIA_INTERNAL_TOKEN: z.string().min(16).default('change-this-media-internal-token'),
  MEDIA_HEARTBEAT_INTERVAL_MS: z.coerce.number().int().min(3000).default(10000),
  MEDIA_MAX_ROOMS: z.coerce.number().int().min(1).default(250),
  MEDIA_MAX_PEERS: z.coerce.number().int().min(1).default(5000),
  MEDIA_HOT_ROOM_PEERS: z.coerce.number().int().min(2).default(250),
  MEDIA_INITIAL_AVAILABLE_OUTGOING_BITRATE: z.coerce.number().int().min(100000).max(5000000).default(800000),
  MEDIA_JOIN_P95_TARGET_MS: z.coerce.number().int().min(50).max(5000).default(750),
  FASTAPI_BASE_URL: z.string().url().default('http://127.0.0.1:8000'),
  CORS_ORIGIN: z.string().default('*'),
  MEDIASOUP_LISTEN_IP: z.string().default('0.0.0.0'),
  MEDIASOUP_ANNOUNCED_IP: z.string().default(''),
  MEDIASOUP_MIN_PORT: z.coerce.number().int().min(1).max(65535).default(40000),
  MEDIASOUP_MAX_PORT: z.coerce.number().int().min(1).max(65535).default(49999),
  SOCKET_PING_TIMEOUT_MS: z.coerce.number().int().min(5000).default(20000),
  SOCKET_PING_INTERVAL_MS: z.coerce.number().int().min(5000).default(25000),
  VERIFY_TIMEOUT_MS: z.coerce.number().int().min(1000).default(6000),
  MEDIA_REGISTRY_DIAGNOSTICS: z.enum(['true', 'false']).default('false'),
  MEDIA_DRAIN_TIMEOUT_MS: z.coerce.number().int().min(1000).default(120000),
});

const parsed = envSchema.parse(process.env);
if (['production', 'prod'].includes(parsed.APP_ENV.toLowerCase())) {
  const unsafe = [];
  if (parsed.MEDIA_INTERNAL_TOKEN.includes('change-this') || parsed.MEDIA_INTERNAL_TOKEN.length < 32) unsafe.push('MEDIA_INTERNAL_TOKEN');
  if (!parsed.MEDIASOUP_ANNOUNCED_IP.trim()) unsafe.push('MEDIASOUP_ANNOUNCED_IP');
  if (parsed.CORS_ORIGIN === '*') unsafe.push('CORS_ORIGIN');
  if (!parsed.MEDIA_PUBLIC_URL.startsWith('https://') || /localhost|127\.0\.0\.1/.test(parsed.MEDIA_PUBLIC_URL)) unsafe.push('MEDIA_PUBLIC_URL');
  if (unsafe.length > 0) throw new Error(`Unsafe production media configuration: ${unsafe.join(', ')}`);
}
const announcedIp = parsed.MEDIASOUP_ANNOUNCED_IP.trim() || detectLanIPv4();

export const config = {
  host: parsed.MEDIA_SERVICE_HOST,
  port: parsed.MEDIA_SERVICE_PORT,
  fastApiBaseUrl: parsed.FASTAPI_BASE_URL.replace(/\/$/, ''),
  corsOrigin: parsed.CORS_ORIGIN,
  verifyTimeoutMs: parsed.VERIFY_TIMEOUT_MS,
  drainTimeoutMs: parsed.MEDIA_DRAIN_TIMEOUT_MS,
  registryDiagnostics: parsed.MEDIA_REGISTRY_DIAGNOSTICS === 'true',
  telemetry: {
    enabled: parsed.OTEL_TRACES_ENABLED === 'true',
    tracesEndpoint: parsed.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT,
    exportTimeoutMs: parsed.OTEL_EXPORT_TIMEOUT_MS,
  },
  registry: {
    nodeId: parsed.MEDIA_NODE_ID.trim() || os.hostname(),
    publicUrl: parsed.MEDIA_PUBLIC_URL.replace(/\/$/, ''),
    internalToken: parsed.MEDIA_INTERNAL_TOKEN,
    heartbeatIntervalMs: parsed.MEDIA_HEARTBEAT_INTERVAL_MS,
    maxRooms: parsed.MEDIA_MAX_ROOMS,
    maxPeers: parsed.MEDIA_MAX_PEERS,
    hotRoomPeers: parsed.MEDIA_HOT_ROOM_PEERS,
  },
  socket: {
    pingTimeout: parsed.SOCKET_PING_TIMEOUT_MS,
    pingInterval: parsed.SOCKET_PING_INTERVAL_MS,
  },
  qos: {
    joinP95TargetMs: parsed.MEDIA_JOIN_P95_TARGET_MS,
    initialAvailableOutgoingBitrate: parsed.MEDIA_INITIAL_AVAILABLE_OUTGOING_BITRATE,
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
