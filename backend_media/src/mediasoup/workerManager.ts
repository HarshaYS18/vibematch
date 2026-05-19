import * as mediasoup from 'mediasoup';
import type { Router, Worker } from 'mediasoup/node/lib/types.js';
import { config } from '../config.js';

const mediaCodecs = [
  {
    kind: 'audio' as const,
    mimeType: 'audio/opus',
    clockRate: 48000,
    channels: 2,
  },
];

export class WorkerManager {
  private worker: Worker | null = null;

  async start(): Promise<void> {
    this.worker = await mediasoup.createWorker({
      rtcMinPort: config.mediasoup.minPort,
      rtcMaxPort: config.mediasoup.maxPort,
      logLevel: 'warn',
      logTags: ['ice', 'dtls', 'rtp', 'srtp', 'rtcp'],
    });

    this.worker.on('died', () => {
      console.error('[mediasoup] worker died; exiting process for supervisor restart.');
      setTimeout(() => process.exit(1), 500);
    });
  }

  async createRouter(): Promise<Router> {
    const worker = this.requireWorker();
    return worker.createRouter({ mediaCodecs });
  }

  close(): void {
    this.worker?.close();
    this.worker = null;
  }

  private requireWorker(): Worker {
    if (!this.worker) {
      throw new Error('mediasoup worker is not started.');
    }
    return this.worker;
  }
}
