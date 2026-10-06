# Chunk 6 — canonical room media architecture

Chunk 6 introduces a platform-neutral room media boundary without changing the
existing FunKey room UI.

## Ownership

```text
RoomSessionRepository
  owns presence / membership / permissions / authoritative seats
             |
             | authorized room intent
             v
RoomMediaEngine
  owns media lifecycle only
             |
       platform factory
        /           \
NativeMediasoupEngine   WebMediasoupEngine
        \           /
   mediasoup/WebRTC compatibility delegate
             |
   LiveRoomAudioService
```

`LiveRoomAudioService` remains the proven low-level production implementation
for this migration chunk. It is no longer a dependency of room feature code;
only the canonical room-media delegate may use it. This prevents a risky SFU
rewrite while establishing the boundary needed to replace the implementation
later.

## Lifecycle guarantees

`DelegatingMediasoupEngine` serializes join, leave, microphone, consume,
reconnect, room-music, and disposal operations. Same-session joins and repeated
consumer requests are deduplicated. A room switch leaves the previous media
session before joining the next one, and `dispose()` is terminal and
idempotent.

Room seat and mic commands are still authorized by the room domain/backend.
The engine receives local media intent only after the authoritative room
snapshot confirms seat/mic state.

## Web / Microsoft Edge

Flutter Web uses `WebMediasoupEngine`, selected in one conditional-import
factory. It is not a dummy or mock implementation: it delegates to the existing
real `flutter_webrtc` + mediasoup transport, producer, and consumer pipeline.

The existing tiny mounted `RTCVideoView` audio elements are preserved because
browser media elements must remain attached for reliable remote audio/autoplay
behavior. Browser/OS output routing is intentionally a no-op in the web adapter;
native speaker routing lives only in `NativeMediasoupEngine`.

If a future browser-specific JS bridge becomes necessary, it belongs behind
`WebMediasoupEngine` and does not change room-domain code.

## Realtime separation

Application realtime (`AppRealtimeHub`) remains separate from room
media/signaling. Chunk 6 does not merge websocket transports.

## Regression guard

The frontend architecture guard now treats `lib/room_media` as a canonical
root and rejects any room feature file that reaches directly into
`LiveRoomAudioService` (except the implementation file itself). Source tests
enforce the same boundary.

No Watch Party, YouTube, OTT, CDN-game, or room visual work is part of this
chunk.
