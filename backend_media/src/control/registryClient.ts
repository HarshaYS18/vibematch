import { randomUUID } from 'node:crypto';
import http from 'node:http';
import https from 'node:https';
import { config } from '../config.js';

export type MediaRuntimeStats = { roomCount: number; peerCount: number; roomIds: string[] };

type RegistryResponse = {
  statusCode: number;
  body: string;
  requestId: string;
  headersElapsedMs: number;
  bodyElapsedMs: number;
};

export class RegistryRequestError extends Error {
  constructor(
    message: string,
    public readonly requestId: string,
    public readonly elapsedMs: number,
    public readonly phase: 'connect_or_headers' | 'body' | 'response',
  ) {
    super(message);
    this.name = 'RegistryRequestError';
  }
}

let lastSuccessfulHeartbeatAt = 0;

export function registryIsHealthy(): boolean {
  return lastSuccessfulHeartbeatAt > 0 && Date.now() - lastSuccessfulHeartbeatAt <= config.registry.heartbeatIntervalMs * 3;
}

export async function heartbeatMediaNode(stats: MediaRuntimeStats): Promise<void> {
  try {
    const response = await requestRegistry('POST', '/api/v1/internal/media/nodes/heartbeat', {
      node_id: config.registry.nodeId,
      public_url: config.registry.publicUrl,
      room_count: stats.roomCount,
      peer_count: stats.peerCount,
      max_rooms: config.registry.maxRooms,
      max_peers: config.registry.maxPeers,
      room_ids: stats.roomIds,
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new RegistryRequestError(`media registry heartbeat failed status=${response.statusCode} body=${response.body}`, response.requestId, response.bodyElapsedMs, 'response');
    }
    lastSuccessfulHeartbeatAt = Date.now();
  } catch (error) {
    lastSuccessfulHeartbeatAt = 0;
    throw error;
  }
}

export async function markMediaNodeOffline(): Promise<void> {
  const response = await requestRegistry('DELETE', `/api/v1/internal/media/nodes/${encodeURIComponent(config.registry.nodeId)}`);
  if ((response.statusCode < 200 || response.statusCode >= 300) && response.statusCode !== 404) {
    throw new RegistryRequestError(`media registry offline failed status=${response.statusCode} body=${response.body}`, response.requestId, response.bodyElapsedMs, 'response');
  }
}

async function requestRegistry(method: 'POST' | 'DELETE', path: string, payload?: Record<string, unknown>): Promise<RegistryResponse> {
  const url = new URL(path, config.fastApiBaseUrl);
  const requestId = randomUUID();
  const body = payload ? JSON.stringify(payload) : undefined;
  const startedAt = performance.now();
  logDiagnostic('start', requestId, 0, { method, path });
  return new Promise<RegistryResponse>((resolve, reject) => {
    let settled = false;
    let headersElapsedMs = 0;
    const finish = (callback: () => void) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      callback();
    };
    // These infrequent control-plane requests deliberately use a fresh socket.
    // A timed-out request therefore cannot poison a later heartbeat through a
    // reused Undici keep-alive connection.
    const client = url.protocol === 'https:' ? https : http;
    const request = client.request(url, {
      method,
      agent: false,
      headers: {
        Accept: 'application/json',
        Connection: 'close',
        'X-Request-ID': requestId,
        'X-Media-Internal-Token': config.registry.internalToken,
        ...(body ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) } : {}),
      },
    });
    const timeout = setTimeout(() => {
      request.destroy(new RegistryRequestError(
        'media registry request timed out',
        requestId,
        elapsed(startedAt),
        headersElapsedMs > 0 ? 'body' : 'connect_or_headers',
      ));
    }, config.verifyTimeoutMs);
    request.once('response', (response) => {
      headersElapsedMs = elapsed(startedAt);
      logDiagnostic('headers', requestId, headersElapsedMs, { statusCode: response.statusCode ?? 0 });
      const chunks: Buffer[] = [];
      response.on('data', (chunk: Buffer) => chunks.push(Buffer.from(chunk)));
      response.once('error', (error) => finish(() => reject(asRegistryError(error, requestId, startedAt, 'body'))));
      response.once('end', () => finish(() => {
        const bodyElapsedMs = elapsed(startedAt);
        logDiagnostic('body_consumed', requestId, bodyElapsedMs, { statusCode: response.statusCode ?? 0 });
        resolve({ statusCode: response.statusCode ?? 0, body: Buffer.concat(chunks).toString('utf8'), requestId, headersElapsedMs, bodyElapsedMs });
      }));
    });
    request.once('error', (error) => finish(() => reject(asRegistryError(error, requestId, startedAt, headersElapsedMs > 0 ? 'body' : 'connect_or_headers'))));
    request.end(body);
  });
}

function asRegistryError(error: Error, requestId: string, startedAt: number, phase: RegistryRequestError['phase']): RegistryRequestError {
  if (error instanceof RegistryRequestError) return error;
  return new RegistryRequestError(`media registry request failed: ${error.message}`, requestId, elapsed(startedAt), phase);
}

function elapsed(startedAt: number): number { return Math.round(performance.now() - startedAt); }

function logDiagnostic(event: string, requestId: string, elapsedMs: number, details: Record<string, unknown>): void {
  if (config.registryDiagnostics) console.info('[media] registry_heartbeat', { event, requestId, elapsedMs, ...details });
}
