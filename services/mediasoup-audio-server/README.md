# Legacy mediasoup Audio SFU MVP

This folder is preserved only as historical reference for the older standalone audio SFU test path.

It is not the active production media service.

Active production media service: `backend_media/`.

Do not run this service together with `backend_media` during current production testing because the ports, auth model, and Socket.IO event contracts are different.

Useful reference only:

- early mediasoup audio-only experiments
- old test target notes
- local TURN notes

Production work should now target:

- `backend/` for source-of-truth permissions
- `backend_media/` for mediasoup signaling and audio/video routing
- `frontend/vibematch_app/lib/features/rooms/data/live_room_audio_service.dart` for the production Flutter audio client
