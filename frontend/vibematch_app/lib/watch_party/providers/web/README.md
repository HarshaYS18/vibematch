# Watch Party Web Provider Runtime

This directory contains the provider-independent embedded OTT WebView boundary
used by Netflix, Prime Video and JioHotstar adapters.

## Authority

The WebView host and HTML5 driver are local playback execution only.
`WatchPartyRepository` and the backend remain authoritative for room Watch
Party session state, revisions, controller identity and timeline commands.

## Resource lifecycle

Chunk 34-M8 adds `WatchPartyWebViewResourceParticipant`, which depends only on
the foundation media-resource lifecycle contract.

The room OTT sheet registers the participant after a concrete WebView controller
is created, unregisters it on normal sheet teardown, and leaves canonical Watch
Party reconciliation untouched.

Backgrounding best-effort pauses embedded playback. Foreground does not force
play. Memory pressure is deliberately non-destructive. Authenticated-session
teardown releases the WebView host.

## Provider/DRM boundary

Do not add provider credential extraction, cookie export, DRM/license bypass,
protected-stream redistribution or private player reverse-engineering here.
Capability probing and companion fallback remain the supported degradation
paths.
