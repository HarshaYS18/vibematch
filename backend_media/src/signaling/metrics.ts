let joinsSucceeded = 0;
let joinsFailed = 0;
const joinDurationBucketsMs = [50, 100, 200, 400, 750, 1000, 2000];
const joinDurationCounts = new Array<number>(joinDurationBucketsMs.length).fill(0);
let joinDurationTotalMs = 0;
let joinDurationObservations = 0;

export function recordJoin(success: boolean, durationMs: number): void {
  if (success) joinsSucceeded += 1;
  else joinsFailed += 1;

  const bounded = Math.max(0, durationMs);
  joinDurationTotalMs += bounded;
  joinDurationObservations += 1;
  for (let index = 0; index < joinDurationBucketsMs.length; index += 1) {
    if (bounded <= joinDurationBucketsMs[index]) joinDurationCounts[index] += 1;
  }
}

export function joinMetrics(): {
  succeeded: number;
  failed: number;
  durationBucketsMs: number[];
  durationCounts: number[];
  durationTotalMs: number;
  durationObservations: number;
} {
  return {
    succeeded: joinsSucceeded,
    failed: joinsFailed,
    durationBucketsMs: [...joinDurationBucketsMs],
    durationCounts: [...joinDurationCounts],
    durationTotalMs: joinDurationTotalMs,
    durationObservations: joinDurationObservations,
  };
}
