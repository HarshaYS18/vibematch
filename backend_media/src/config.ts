import 'dotenv/config';
import { z } from 'zod';

const envSchema = z.object({
  MEDIA_SERVICE_HOST: z.string().default('0.0.0.0'),
  MEDIA_SERVICE_PORT: z.coerce.number().int().min(1).max(65535).default(4100),
  FASTAPI_BASE_URL: z.string().url().default('http://127.0.0.1:8000'),
  CORS_ORIGIN: z.string().default('*'),
  MEDIASOUP_LISTEN_IP: z.string().default('0.0.0.0'),
  MEDIASOUP_ANNOUNCED_IP: z.string().default('127.0.0.1'),
  MEDIASOUP_MIN_PORT: z.coerce.number().int().min(1).max(65535).default(40000),
  MEDIASOUP_MAX_PORT: z.coerce.number().int().min(1).max(65535).default(49999),
  SOCKET_PING_TIMEOUT_MS: z.coerce.number().int().min(5000).default(20000),
  SOCKET_PING_INTERVAL_MS: z.coerce.number().int().min(5000).default(25000),
  VERIFY_TIMEOUT_MS: z.coerce.number().int().min(1000).default(6000),
});

const parsed = envSchema.parse(process.env);

export const config = {
  host: parsed.MEDIA_SERVICE_HOST,
  port: parsed.MEDIA_SERVICE_PORT,
  fastApiBaseUrl: parsed.FASTAPI_BASE_URL.replace(/\/$/, ''),
  corsOrigin: parsed.CORS_ORIGIN,
  verifyTimeoutMs: parsed.VERIFY_TIMEOUT_MS,
  socket: {
    pingTimeout: parsed.SOCKET_PING_TIMEOUT_MS,
    pingInterval: parsed.SOCKET_PING_INTERVAL_MS,
  },
  mediasoup: {
    listenIp: parsed.MEDIASOUP_LISTEN_IP,
    announcedIp: parsed.MEDIASOUP_ANNOUNCED_IP,
    minPort: parsed.MEDIASOUP_MIN_PORT,
    maxPort: parsed.MEDIASOUP_MAX_PORT,
  },
};
