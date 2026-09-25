# Room Media Runtime

This directory contains lifecycle adapters for the canonical room media engine.

## Authority

`RoomMediaEngine` owns only mediasoup/WebRTC transport state and local media
intent. Durable room membership, seats, permissions and room state remain
backend/`RoomSessionRepository` authority.

## Chunk 34-M9 lifecycle

`RoomMediaResourceParticipant` exposes the existing engine through the
foundation `MediaResourceRegistry` contract. It does not create another media
engine or import the concrete AppShell coordinator.

Foreground recovery calls `reconnect()` only when a media session is active or
joining. Background and memory-pressure events are non-destructive. Session
release calls `leave()`, not terminal `dispose()`, because the engine is
owned by the reusable `LiveRoomMediaSignalingService` singleton.

Registration lifetime follows media configure/leave rather than route widget
lifetime so minimized rooms remain managed.
