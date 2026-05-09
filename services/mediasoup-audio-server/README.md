# VibeMatch mediasoup Audio SFU MVP

This folder contains the standalone audio-only WebRTC SFU test server for the MVP branch.

The goal of this branch is to keep the newer `search-page-modular-v1` real app pages as the base, then add a safe WebRTC test path from the mediasoup branch without overwriting the modular UI work.

## What this tests

- Audio-only WebRTC through mediasoup.
- Multi-room SFU behavior.
- 17 speaker seats per room.
- Audience users can join and consume audio.
- Seated users can publish microphone audio.
- Self mute and admin mute state in the room seat state.
- Local Android emulator / local laptop testing.

## Server setup

```bash
cd services/mediasoup-audio-server
cp .env.example .env
npm install
npm run check
npm start
```

Health check:

```bash
curl http://127.0.0.1:4000/health
```

Stats check:

```bash
curl http://127.0.0.1:4000/stats
```

## Flutter test app

From the Flutter app folder:

```bash
cd frontend/vibematch_app
flutter pub get
flutter run -t lib/main_mediasoup_test.dart
```

For Android emulator testing, keep the test page server URL as:

```txt
http://10.0.2.2:4000
```

For a real phone on the same Wi-Fi, change both `.env` and the test page input to your laptop Wi-Fi IP, for example:

```env
ANNOUNCED_IP=192.168.1.8
TURN_HOST=192.168.1.8
```

Then use:

```txt
http://192.168.1.8:4000
```

## Local auth mode

For MVP local testing, `.env.example` sets:

```env
REQUIRE_AUDIO_TOKEN=false
```

That lets the standalone Flutter mediasoup test page connect directly. Later, when FastAPI audio-session token generation is wired, change it to `true` and pass short-lived audio tokens from the app.

## Optional local TURN

```bash
docker compose -f docker-compose.turn.yml up -d
```

For production, do not use the static local TURN credentials from this MVP file. Generate short-lived TURN credentials from the backend.

## Current branch behavior

The normal VibeMatch app pages remain from `search-page-modular-v1`. WebRTC is added as a standalone test target first:

```txt
frontend/vibematch_app/lib/main_mediasoup_test.dart
```

This is intentional. It lets us validate real publish/consume audio before wiring it into the production Live Room seat UI, where we must preserve room moderation, seat states, gifts, chat, mini profile, and all existing modular UI behavior.

## Next production wiring step

After this test path works on two devices/emulators:

1. Create a `RoomAudioEngine` abstraction over the mediasoup engine.
2. Connect it to `LiveRoomPage` seat join/leave/mute actions.
3. Ask FastAPI for short-lived audio session tokens.
4. Enforce room permissions before joining/publishing.
5. Add reconnect recovery and backend room state sync.
