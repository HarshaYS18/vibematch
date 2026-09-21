import { config } from '../config.js';
import type { MediaAction, MediaVerifyResponse } from '../types/mediaTypes.js';

export class MediaAuthorizationError extends Error {
  constructor(
    message: string,
    public readonly statusCode = 403,
    public readonly reason?: string | null,
  ) {
    super(message);
    this.name = 'MediaAuthorizationError';
  }
}

export async function verifyMediaAction(params: {
  bearerToken: string;
  requestedAction: MediaAction;
  roomPublicId?: string;
  deviceId?: string;
}): Promise<MediaVerifyResponse> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), config.verifyTimeoutMs);

  try {
    const response = await fetch(`${config.fastApiBaseUrl}/api/v1/media-realtime/verify`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${params.bearerToken}`,
        'X-Media-Internal-Token': config.registry.internalToken,
      },
      body: JSON.stringify({
        room_public_id: params.roomPublicId ?? null,
        device_id: params.deviceId ?? null,
        requested_action: params.requestedAction,
        media_node_id: config.registry.nodeId,
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      const body = await response.text();
      throw new MediaAuthorizationError(
        `FastAPI verification failed with status ${response.status}: ${body}`,
        response.status,
      );
    }

    const result = (await response.json()) as MediaVerifyResponse;
    if (!result.allowed) {
      throw new MediaAuthorizationError(
        result.reason ?? 'Media action denied by FastAPI source-of-truth.',
        403,
        result.reason,
      );
    }
    return result;
  } catch (error) {
    if (error instanceof MediaAuthorizationError) throw error;
    if (error instanceof Error && error.name === 'AbortError') {
      throw new MediaAuthorizationError('FastAPI verification timed out.', 504);
    }
    throw new MediaAuthorizationError(
      error instanceof Error ? error.message : 'Unknown FastAPI verification failure.',
      500,
    );
  } finally {
    clearTimeout(timeout);
  }
}

export function extractBearerToken(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  if (trimmed.toLowerCase().startsWith('bearer ')) {
    return trimmed.slice(7).trim() || null;
  }
  return trimmed;
}
