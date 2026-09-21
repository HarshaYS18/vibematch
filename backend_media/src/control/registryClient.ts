import { config } from '../config.js';

export type MediaRuntimeStats = {
  roomCount: number;
  peerCount: number;
  roomIds: string[];
};

let lastSuccessfulHeartbeatAt = 0;

export function registryIsHealthy(): boolean {
  if (lastSuccessfulHeartbeatAt <= 0) return false;
  return Date.now() - lastSuccessfulHeartbeatAt <= config.registry.heartbeatIntervalMs * 3;
}

export async function heartbeatMediaNode(stats: MediaRuntimeStats): Promise<void> {
  const response = await fetch(`${config.fastApiBaseUrl}/api/v1/internal/media/nodes/heartbeat`, {
    method: 'POST',
    signal: AbortSignal.timeout(config.verifyTimeoutMs),
    headers: {
      'Content-Type': 'application/json',
      'X-Media-Internal-Token': config.registry.internalToken,
    },
    body: JSON.stringify({
      node_id: config.registry.nodeId,
      public_url: config.registry.publicUrl,
      room_count: stats.roomCount,
      peer_count: stats.peerCount,
      max_rooms: config.registry.maxRooms,
      max_peers: config.registry.maxPeers,
      room_ids: stats.roomIds,
    }),
  });

  if (!response.ok) {
    throw new Error(`media registry heartbeat failed status=${response.status} body=${await response.text()}`);
  }
  lastSuccessfulHeartbeatAt = Date.now();
}

export async function markMediaNodeOffline(): Promise<void> {
  const response = await fetch(
    `${config.fastApiBaseUrl}/api/v1/internal/media/nodes/${encodeURIComponent(config.registry.nodeId)}`,
    {
      method: 'DELETE',
      signal: AbortSignal.timeout(config.verifyTimeoutMs),
      headers: {
        'X-Media-Internal-Token': config.registry.internalToken,
      },
    },
  );
  if (!response.ok && response.status !== 404) {
    throw new Error(`media registry offline failed status=${response.status}`);
  }
}
