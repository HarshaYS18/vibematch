# Production Realtime Media Architecture

## Active Media Path

FastAPI remains the source of truth for room access, permissions, room state, seats, kicks, roles, and profile/economy display data.

The active production media stack is:

1. Flutter `LiveRoomPage`
2. `LiveRoomMediaSignalingService`
3. `LiveRoomAudioService`
4. `backend_media` Node service on port `4100`
5. mediasoup transports, producers, and consumers

`backend_media` only routes realtime media. It verifies sensitive actions with FastAPI before joining rooms, creating or connecting transports, producing audio, consuming audio, and producer actions.

## Legacy Media Folders

These folders are legacy/reference only and must not be started as production services:

- `audio-server/`
- `media-server/`
- `services/mediasoup-audio-server/`
- `frontend/vibematch_app/lib/features/audio_mediasoup/`

## Audio Fixes Completed

- `joinRoom` is idempotent per backend media socket for the same room.
- Repeated `joinRoom` returns the existing peer/session payload and logs `[media] joinRoom.reused`.
- Send and receive WebRTC transports are reused per peer direction.
- Transport reuse logs `[media] transport.reused`.
- A peer can consume a given producer only once.
- Duplicate consume requests return the existing consumer payload and log `[media] consume.reused`.
- Duplicate mic producers are replaced by closing the old producer and notifying the room once.
- Disconnect, leave, close producer, and duplicate producer replacement clean producer/consumer/transport state.
- `backend_media` now logs the mediasoup listen/announced IP on startup. Local dev defaults to auto-detecting the LAN IPv4 address when `MEDIASOUP_ANNOUNCED_IP` is empty, because advertising `127.0.0.1` makes WebRTC signaling succeed while remote devices cannot receive RTP.
- Flutter audio join now has an in-flight guard.
- Flutter receive transport creation and consume loops are idempotent.
- Flutter treats the server `produce` ack as the canonical mic producer state, preventing the producer watchdog from creating a second mic producer after a successful ack.
- Flutter remote audio renderers remain mounted in the visible page tree as tiny `RTCVideoView` widgets.
- Flutter Web no longer forces speakerphone output routing.

## Seat Action Pill

The live-room seat UI should keep the established admin action pill. Media work must not redesign or replace that pill. Normal users still use the existing take-seat/apply-seat path and do not see admin-only controls.

## Deferred Work

- Manual cross-browser audio validation is still required to confirm browser autoplay/output behavior after signaling succeeds.
- Relationship between room seat state and media producer state can be made richer later by adding canonical producer IDs into FastAPI room snapshots.
- Legacy media folders should stay in place until the team decides on a cleanup/migration window.
