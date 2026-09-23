# Room state replay / desynchronization

Use this runbook when room clients repeatedly resync, replay fallback rises, versions appear stale, or a client reports a sequence gap.

## Signals

Inspect:
- `funkey_room_replay_attempts_total`;
- `funkey_room_replay_success_total`;
- `funkey_room_replay_fallback_total`;
- `funkey_room_sequence_failures_total`;
- realtime Redis availability/memory/evictions;
- API and Go realtime error/reconnect rates;
- PostgreSQL latency and lock pressure.

A transport sequence gap is not evidence of durable data loss.

## Triage

1. Confirm PostgreSQL is healthy and migrations include `20260923_0200`.
2. Identify whether realtime Redis failed over, restarted, evicted keys, or exceeded connection/memory limits.
3. Check whether fallback is expected because the client was disconnected longer than the five-minute/256-event replay window.
4. Verify clients can fetch one authoritative room snapshot.
5. Confirm snapshot `state_version` and `event_sequence` advance after an authoritative room mutation.

## Safe recovery

Allow clients to fall back to snapshots. Restore realtime Redis health and let a new transport epoch form if needed. A changed Redis epoch is expected after loss/rebuild.

If a specific room projection looks stale, compare PostgreSQL room/current-state rows and the latest durable room events. Reconnect clients after confirming authority is correct.

## Do not

Do not reconstruct room membership, seats, moderation, Watch Party, or activity truth from Redis replay entries.

Do not manually force Redis transport sequence to match PostgreSQL `event_sequence`; they are intentionally different counters.

Do not delete PostgreSQL event/current-state rows to repair a client gap.

Do not extend replay retention without measuring Redis memory and event volume.

## Recovery validation

Validate join -> snapshot, mutation -> delta, short disconnect -> replay, and old/trimmed stream -> snapshot fallback. Confirm replay-fallback and sequence-failure rates return to normal.
