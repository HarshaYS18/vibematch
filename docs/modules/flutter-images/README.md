# Flutter Images

## Purpose

Provide one decode-sizing and speculative-prefetch standard for high-frequency
Flutter images.

## Contracts

- use `foundation/images/AppImage` on guarded hot network-image surfaces;
- pass logical render width/height so decode targets match physical display
  size instead of full uploaded resolution;
- keep Flutter's native ImageCache as the shared decoded cache;
- use `AppImagePrefetchQueue` for speculative loading rather than unbounded
  ad-hoc `precacheImage` loops.

## Resource behavior

The prefetch queue is capped at 2 active + 12 queued jobs and registers as
`MediaResourceKind.imagePrefetch`. Background, memory pressure and session
teardown invalidate queued work. M5 separately owns shared ImageCache trimming.

## Authority

Profile/content domains still own URLs and upload state. This module owns only
presentation decode/prefetch policy.
