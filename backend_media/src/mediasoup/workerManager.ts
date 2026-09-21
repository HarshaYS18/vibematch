import * as mediasoup from 'mediasoup';
import { config } from '../config.js';
import type { MediaRouter, MediaWorker } from '../types/mediaTypes.js';

const mediaCodecs = [
  {
    kind: 'audio' as const,
    mimeType: 'audio/opus',
    clockRate: 48000,
    channels: 2,
  },
  { kind: 'video' as const, mimeType: 'video/VP8', clockRate: 90000 },
];

export class WorkerManager {
  private worker: MediaWorker | null = null;
  private readonly deathHandlers = new Set<() => void>();

  async start(): Promise<void> {
    this.worker = (await mediasoup.createWorker({
      rtcMinPort: config.mediasoup.minPort,
      rtcMaxPort: config.mediasoup.maxPort,
      logLevel: 'warn',
      logTags: ['ice', 'dtls', 'rtp', 'srtp', 'rtcp'],
    })) as unknown as MediaWorker;

    this.worker.on('died', () => {
      this.worker = null;
      console.error('[mediasoup] worker died; draining process for supervisor restart.');
      for (const handler of this.deathHandlers) handler();
    });
  }

  onDied(handler: () => void): void {
    this.deathHandlers.add(handler);
  }

  async createRouter(): Promise<MediaRouter> {
    const worker = this.requireWorker();
    return worker.createRouter({ mediaCodecs });
  }

  get isReady(): boolean {
    return this.worker !== null;
  }

  close(): void {
    this.worker?.close();
    this.worker = null;
  }

  private requireWorker(): MediaWorker {
    if (!this.worker) {
      throw new Error('mediasoup worker is not started.');
    }
    return this.worker;
  }
}
