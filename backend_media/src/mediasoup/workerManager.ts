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
];

export class WorkerManager {
  private worker: MediaWorker | null = null;

  async start(): Promise<void> {
    this.worker = (await mediasoup.createWorker({
      rtcMinPort: config.mediasoup.minPort,
      rtcMaxPort: config.mediasoup.maxPort,
      logLevel: 'warn',
      logTags: ['ice', 'dtls', 'rtp', 'srtp', 'rtcp'],
    })) as unknown as MediaWorker;

    this.worker.on('died', () => {
      console.error('[mediasoup] worker died; exiting process for supervisor restart.');
      setTimeout(() => process.exit(1), 500);
    });
  }

  async createRouter(): Promise<MediaRouter> {
    const worker = this.requireWorker();
    return worker.createRouter({ mediaCodecs });
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
