import { z } from 'zod';

export const joinRoomSchema = z.object({
  roomPublicId: z.string().min(1).max(80).optional(),
  roomId: z.string().min(1).max(80).optional(),
  deviceId: z.string().max(255).optional(),
}).transform((value) => ({
  ...value,
  roomPublicId: value.roomPublicId ?? value.roomId ?? '',
}));

export const createTransportSchema = z.object({
  direction: z.enum(['send', 'recv']),
});

export const connectTransportSchema = z.object({
  transportId: z.string().min(1),
  dtlsParameters: z.unknown(),
});

export const produceSchema = z.object({
  transportId: z.string().min(1),
  kind: z.enum(['audio', 'video']),
  rtpParameters: z.unknown(),
  appData: z.record(z.unknown()).optional().default({}),
});

export const consumeSchema = z.object({
  transportId: z.string().min(1).optional(),
  producerId: z.string().min(1),
  rtpCapabilities: z.unknown(),
});

export const producerActionSchema = z.object({
  producerId: z.string().min(1),
});

export const consumerActionSchema = z.object({
  consumerId: z.string().min(1),
});

export const roomMusicStartSchema = z.object({
  url: z.string().url().max(2000),
  title: z.string().max(200).optional().default('Room music'),
  seekMs: z.coerce.number().int().min(0).max(24 * 60 * 60 * 1000).optional().default(0),
});

export const roomMusicStopSchema = z.object({}).passthrough();

export const leaveRoomSchema = z.object({
  roomPublicId: z.string().min(1).max(80).optional(),
  roomId: z.string().min(1).max(80).optional(),
});

export const socketAuthSchema = z.object({
  token: z.string().min(1),
  deviceId: z.string().max(255).optional(),
});
