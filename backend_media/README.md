# VibeMatch Media Service

Production-style Node/TypeScript mediasoup signaling service for VibeMatch/FunKey realtime audio.

FastAPI remains the source of truth for:

- user authentication
- active/banned/device-banned checks
- room existence and active status
- locked room access
- Secret Vibe access
- members-only access
- room kickout status
- apply-only mic restrictions
- admin-muted seat restrictions
- official/owner/admin/member context

The media service never trusts client-sent user ids, roles, or permissions. Every sensitive media action calls FastAPI `POST /media-realtime/verify` using the user's Bearer token.

## Local setup

```powershell
cd "D:\Vibe Match\vibematch\backend_media"
copy .env.example .env
npm install
npm run typecheck
npm run build
npm run dev
```

FastAPI should be running before joining rooms:

```powershell
cd "D:\Vibe Match\vibematch\backend"
uvicorn app.main:app --reload
```

Health check:

```powershell
curl http://127.0.0.1:4100/health
```

## Required env

```env
MEDIA_SERVICE_HOST=0.0.0.0
MEDIA_SERVICE_PORT=4100
FASTAPI_BASE_URL=http://127.0.0.1:8000
CORS_ORIGIN=*

MEDIASOUP_LISTEN_IP=0.0.0.0
MEDIASOUP_ANNOUNCED_IP=127.0.0.1
MEDIASOUP_MIN_PORT=40000
MEDIASOUP_MAX_PORT=49999
```

For VPS production, set `MEDIASOUP_ANNOUNCED_IP` to the public server IP or the public IP used by clients.

Open firewall ports:

- media service signaling port, default `4100`
- mediasoup RTC UDP/TCP range, default `40000-49999`

## Socket auth

Client connects with Socket.IO auth:

```json
{
  "token": "Bearer <access_token>",
  "deviceId": "web-install-..."
}
```

The token is passed to FastAPI for verification. The media service does not decode or trust client identity by itself.

## Signaling events

### `joinRoom`

Calls FastAPI with `requested_action = join_room`.

Payload:

```json
{
  "roomPublicId": "6418ROOM123",
  "deviceId": "web-install-..."
}
```

Response data:

```json
{
  "roomPublicId": "6418ROOM123",
  "rtpCapabilities": {},
  "peer": {},
  "permissions": [],
  "mediasoupContext": {}
}
```

### `getRouterRtpCapabilities`

Returns room router RTP capabilities after join.

### `createWebRtcTransport`

Calls FastAPI with `requested_action = create_transport`.

Payload:

```json
{
  "direction": "send"
}
```

Direction can be `send` or `recv`.

### `connectWebRtcTransport`

Calls FastAPI with `requested_action = connect_transport`.

Payload:

```json
{
  "transportId": "...",
  "dtlsParameters": {}
}
```

### `produce`

Calls FastAPI with `requested_action = produce_audio`.

Payload:

```json
{
  "transportId": "...",
  "kind": "audio",
  "rtpParameters": {},
  "appData": {}
}
```

Only audio is enabled in this foundation. Video should be added after audio is stable.

### `consume`

Calls FastAPI with `requested_action = consume_audio`.

Payload:

```json
{
  "producerId": "...",
  "rtpCapabilities": {}
}
```

### `resumeConsumer`

Payload:

```json
{
  "consumerId": "..."
}
```

### `pauseProducer`, `resumeProducer`, `closeProducer`

Calls FastAPI with producer action verification.

Payload:

```json
{
  "producerId": "..."
}
```

### `leaveRoom`

Closes all transports/producers/consumers for the socket and cleans empty rooms.

## Broadcast events

The media service emits:

- `connected`
- `peerJoined`
- `peerLeft`
- `newProducer`
- `producerClosed`

## Production notes

- Run this service under a process manager such as systemd, PM2, or Docker.
- Use HTTPS/WSS behind Nginx/Caddy in production.
- Keep FastAPI and Node service on a private network if possible.
- `POST /media-realtime/verify` must remain the permission gate before every sensitive mediasoup action.
- Do not let clients pass `user_id`, `public_user_id`, roles, or room permission flags to mediasoup directly.
- Add rate limiting at Nginx or service level before public beta.
- Use sticky sessions if horizontally scaling Socket.IO, or add Redis adapter later.

## Current scope

Completed foundation:

- Socket.IO server
- mediasoup worker/router setup
- room manager
- send/recv WebRTC transport creation
- transport connect
- audio produce
- audio consume
- producer pause/resume/close
- leave/disconnect cleanup
- FastAPI permission verification per sensitive action

Deferred intentionally:

- video media codecs
- horizontal scaling with Redis adapter
- recording/transcoding
- TURN/STUN production tuning
- Flutter live-room media client wiring
- native call overlay and push notification wakeups
