let joinsSucceeded = 0;
let joinsFailed = 0;

export function recordJoin(success: boolean): void {
  if (success) joinsSucceeded += 1;
  else joinsFailed += 1;
}

export function joinMetrics(): { succeeded: number; failed: number } {
  return { succeeded: joinsSucceeded, failed: joinsFailed };
}
