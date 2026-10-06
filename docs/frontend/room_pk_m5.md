# M5 — Room-vs-Room PK / Battle Mode

## Product constraint

M5 adds PK without redesigning FunKey. The only persistent entry point is one
new `Room PK` row inside the existing Live Room **Settings > Modes** section.
The existing room shell, seats, chat, input dock, gifts and navigation remain
unchanged.

PK presentation uses temporary FunKey-native overlays and one compact live score
strip.

## Match flow

1. A host/admin opens Room PK from the existing Modes section.
2. Room Control returns currently online, public, non-busy rooms.
3. The host chooses a room and 2, 3 or 5 minute battle duration.
4. The target room host/admin receives an in-room challenge overlay.
5. Accepting the challenge changes durable PK state to `active`.
6. Both rooms receive the same authoritative `room_pk/state` realtime event.
7. A short VS intro overlay runs, then the normal room returns with a compact
   live score strip.
8. Successfully settled room gifts increment that room's score.
9. At the authoritative end, Room Control calculates the winner.
10. The winning room receives a temporary victory celebration. The losing room
    receives a respectful result overlay; a tie receives a draw result.

## VS animation

The successful-match intro is a temporary overlay:

- both room identities move in from opposite sides;
- a central FunKey-colored VS impact is shown;
- the overlay lasts about 3.2 seconds;
- it does not pause realtime synchronization;
- users requesting reduced motion receive a static/near-instant transition.

No permanent PK screen or Hago UI is introduced.

## Victory celebration

The winner is never inferred from the client score bar. The celebration is
shown only when `winner_room_id` arrives from Room Control.

The winning room receives a trophy, score result and lightweight confetti using
FunKey's palette plus a gold victory accent. Reduced-motion users receive the
static result without moving particles. The losing room is not humiliated and
receives a subdued finished state.

## Authority

- PostgreSQL / Room Control: PK challenge, state, scores, final result, winner.
- Economy: gift/wallet settlement remains sole financial authority.
- Core Economy integration: after settlement commits, an idempotent score
  receipt is sent to Room Control for low-latency live scoring.
- Finalization: Room Control rebuilds both scores from Economy's settled
  `gift_transactions` in the exact PK time window before choosing the winner.
- Redis / Go gateway: replay/fanout only.
- Flutter: presentation only.

The unique score receipt source ID prevents a successful gift from counting
twice after retries.

If Room Control is temporarily unavailable after a gift commits, the gift
settlement remains valid. A live score may temporarily lag, but finalization
reconciles against the settled Economy ledger, so a missed realtime receipt
cannot change the durable winner. Money is never rolled back by a
presentation/game-mode failure.

## Mode compatibility

A room cannot start Cricket, Watch Party or VibeSync while PK is pending/live,
and PK cannot start while Cricket Mode is active. This prevents multiple room
activity modes from fighting over the same interaction surface.

## Timer/finalization

Each connected room client schedules an authoritative refresh at the server
`ends_at` timestamp. Room Control finalizes an overdue active match when
authoritative state is requested. PK also listens to the existing realtime
resync stream and reloads its authoritative snapshot after reconnect/sequence
gaps. Finished matches remain eligible for current-state recovery only for a
short bounded window, and each match result animation is presented at most once
per client controller. Final score/winner remains durable independently of the
visual animation window.

## Non-goals

M5 deliberately excludes:

- Karaoke;
- permanent room redesign;
- client-side winner calculation;
- gambling/wagers;
- cross-room media mixing beyond existing room media;
- 3D battle scenes.

## Validation

M5 is complete only when migrations, backend tests, Flutter tests, analyzer,
production web build and all repository architecture/security/platform
workflows pass on one frozen authoritative HEAD.
