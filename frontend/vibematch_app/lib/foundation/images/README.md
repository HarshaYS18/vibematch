# Foundation Images

This module owns generic Flutter image-presentation infrastructure, not image
content/domain authority.

## AppImage

`AppImage` wraps Flutter's native network/asset image widgets and applies
bounded decode dimensions based on logical render size and device pixel ratio.
It does not introduce another disk cache or image database.

Flutter's shared decoded ImageCache is managed separately by the Chunk 34-M5
resource participant. The former standalone speculative prefetch queue was
removed after reachability analysis proved that no production surface used it.
Visible image loading behavior is unchanged.
