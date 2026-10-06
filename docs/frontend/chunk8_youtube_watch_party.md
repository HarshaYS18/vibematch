# Chunk 8 — YouTube Watch Party

Chunk 8 adds the first integrated provider implementation on top of the
provider-independent Watch Party core from Chunk 7.

## Provider boundary

```text
RoomSessionRepository
        |
WatchPartyRepository
        |
WatchPartyCoordinator
        |
YoutubeWatchAdapter
        |
YoutubePlayerPort
        |
official YouTube IFrame player
```

The player never becomes a second Watch Party authority. Controller intents still
flow through the canonical backend command endpoint and all clients reconcile
from the authoritative WatchSession projected through room state.

## Content normalization

YouTube video IDs are normalized from direct IDs and supported YouTube URL forms
including watch, youtu.be, shorts, embed, live and music.youtube.com URLs.

## Drift correction

The YouTube IFrame API supports playback-rate changes, but rates are discrete and
an unsupported suggested rate may be rounded. Therefore the provider advertises
playback-rate control while disabling fine-grained rate correction. Medium drift
uses an authoritative seek instead of relying on 0.95/1.05 corrections that the
player may round back to 1.0.

## UI

The existing Watch Party entry and room visual language are preserved. Provider
controls are presented through the room Watch Party surface; room voice, chat,
seats, gifts and other room state continue independently.

## Explicitly deferred

Netflix, Prime Video and JioHotstar remain Chunk 9. Chunk 8 does not introduce
DRM circumvention, provider scraping, private provider APIs, content restreaming,
or a second Watch Party socket.
