# VibeMatch WebRTC Small Beta Runbook

Branch: `mediasoup-audio-sfu-poc`

## Goal

This runbook is for controlled small-beta WebRTC audio testing using the mediasoup SFU path wired into Live Room.

## Services

Run three processes during local beta testing:

```bash
# 1. FastAPI backend
cd backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000

# 2. mediasoup SFU
cd services/mediasoup-audio-server
copy .env.example .env
npm install
npm run dev

# 3. Flutter app
cd frontend/vibematch_app
flutter pub get
flutter run
```

## Required environment

The mediasoup `.env` JWT settings must match the FastAPI backend JWT settings:

```env
JWT_SECRET_KEY=change-this-secret-key-in-production
JWT_ALGORITHM=HS256
REQUIRE_AUDIO_TOKEN=true
```

For real phone testing on the same Wi-Fi, set:

```env
ANNOUNCED_IP=YOUR_LAPTOP_OR_SERVER_IP
TURN_HOST=YOUR_LAPTOP_OR_SERVER_IP
```

And update Flutter:

```dart
AppConstants.apiBaseUrl = 'http://YOUR_LAPTOP_OR_SERVER_IP:8000';
AppConstants.mediasoupAudioServerUrl = 'http://YOUR_LAPTOP_OR_SERVER_IP:4000';
```

## Health checks

```bash
curl http://127.0.0.1:4000/health
curl http://127.0.0.1:4000/ready
curl http://127.0.0.1:4000/stats
```

Expected:

- `/health` returns `ok: true`
- `/ready` returns HTTP 200 and `ok: true`
- `/stats` shows active rooms, peers, producers, consumers, transports, and worker load

## Small beta acceptance checklist

### Single-room 2-device test

- Device A logs in
- Device B logs in
- Both enter the same Live Room ID
- Both receive FastAPI audio session token
- Both join mediasoup SFU
- Device A takes seat 1
- Device A publishes mic
- Device B hears Device A
- Device B takes seat 2
- Device B publishes mic
- Device A hears Device B
- Mute/unmute works for both
- Leaving seat stops publishing
- Leaving room disconnects SFU

### Multi-room isolation test

- Device A and B join `VM1001`
- Device C joins `VM1002`
- Device C must not hear `VM1001`
- `/stats` must show separate rooms

### Rejoin test

- Device A publishes mic
- Device A leaves room
- Device A rejoins same room
- Device A can publish again
- Other devices consume the new producer

### Network test

- Toggle Wi-Fi off/on
- App should show audio error/retry path, not crash
- Rejoin room audio should work after retry

### TURN test

- Test one phone on Wi-Fi and one phone on mobile data
- Confirm remote audio still works through TURN
- Verify coturn logs show relay usage if direct UDP fails

## Known small-beta limitations

- Room access validation is started with audio session tokens but must still be expanded to full locked room, Secret Vibe, members-only, room ban, and room mute rules.
- Server deployment is not yet multi-region.
- Load limits are not final until real load testing.
- Advanced reconnect/ICE restart behavior is still beta-level.
- Monitoring is basic health/stats endpoint based.

## Rollback

To disable WebRTC Live Room audio and keep the UI safe:

```dart
AppConstants.useMediasoupAudioInLiveRoom = false;
```

Then rebuild Flutter.
