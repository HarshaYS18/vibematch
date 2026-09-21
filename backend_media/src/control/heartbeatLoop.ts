export class HeartbeatLoop {
  private timer: NodeJS.Timeout | undefined;
  private inFlight: Promise<void> | undefined;

  constructor(private readonly intervalMs: number, private readonly send: () => Promise<void>) {}

  start(): void {
    void this.trigger();
    this.timer = setInterval(() => void this.trigger(), this.intervalMs);
  }

  async trigger(): Promise<void> {
    if (this.inFlight) return this.inFlight;
    this.inFlight = this.send().finally(() => { this.inFlight = undefined; });
    return this.inFlight;
  }

  stop(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = undefined;
  }

  async waitForIdle(): Promise<void> {
    await this.inFlight;
  }
}
