# Chunk 13: Buttery performance standard

Performance is an ongoing contract.

- 60 Hz frame deadline: 16.67 ms.
- 120 Hz frame deadline: 8.33 ms.

Implemented standards:
- persistent main-tab screens through `_PersistentTabStage`;
- lazy sliver/list rendering;
- decode-sized network images on high-frequency surfaces;
- AppShell-scoped Vibes playback arbitration rather than process-global state;
- lazy feed video-controller creation and disposal when far from viewport;
- one active feed video key at a time;
- repaint isolation around feed media;
- in-flight GET deduplication at the canonical network boundary;
- bounded repository caches where appropriate (remote games and Events);
- memory-pressure handling that releases Vibes ownership, live image entries and game bundle cache.

Release profiling must be done in Flutter profile mode on real Android hardware while scrolling Home/Vibes, entering rooms, using Watch Party, and opening/closing remote games. Inspect UI/raster frame times, memory growth, media decoder count, image-cache pressure and duplicated network requests.


## Chunk 34-M13 image pipeline hardening

The Chunk 13 image-sizing rule is now centralized in
`foundation/images/AppImage` rather than repeated ad hoc on hot avatar
surfaces.

Decode dimensions use logical render size × device pixel ratio with a hard
maximum dimension. Vibes avatars, shared avatar frames and the Story viewer
avatar are guarded against raw `Image.network`/`NetworkImage` usage.

Speculative image loading uses a bounded `AppImagePrefetchQueue` (2 concurrent,
12 queued). The queue is lifecycle-aware and drops speculative work on
background/memory pressure/session teardown, while M5 independently trims the
shared decoded image cache.
