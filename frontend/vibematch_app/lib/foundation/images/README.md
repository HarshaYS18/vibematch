# Foundation Images

This module owns generic Flutter image-presentation infrastructure, not image
content/domain authority.

## AppImage

`AppImage` wraps Flutter's native network/asset image widgets and applies
bounded decode dimensions based on logical render size and device pixel ratio.
It does not introduce another disk cache or image database.

## Prefetch

`AppImagePrefetchQueue` performs bounded speculative network-image prefetching:
2 concurrent requests and 12 queued requests by default.

Inside the authenticated AppShell subtree the queue registers as
`MediaResourceKind.imagePrefetch`. Backgrounding, memory pressure and session
teardown invalidate speculative queued work. In-flight work that completes after
invalidation is evicted.

Visible image loading never waits on prefetch. Flutter's shared decoded
ImageCache remains managed separately by the Chunk 34-M5 resource participant.


## Scoped provider dependency

`appImagePrefetchQueueProvider` explicitly depends on
`mediaResourceRegistryProvider`, ensuring the queue resolves inside the
authenticated AppShell resource-registry override.
