# Flutter Images

## Purpose

Provide one decode-sizing standard for high-frequency Flutter images without a
second image cache or speculative runtime.

## Contracts

- use `foundation/images/AppImage` on guarded hot network-image surfaces;
- pass logical render width/height so decode targets match physical display
  size instead of full uploaded resolution;
- keep Flutter's native ImageCache as the shared decoded cache;
- do not add an independent prefetch queue unless a measured production need
  justifies and wires it to a real surface.

## Resource behavior

Flutter's shared decoded ImageCache remains lifecycle-managed by the
`MediaResourceKind.flutterImageCache` participant. The former standalone
prefetch queue was removed because no production surface imported it.

## Authority

Profile/content domains still own URLs and upload state. This module owns only
presentation decode policy.
