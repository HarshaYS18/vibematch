# VIP/SVIP CDN asset paths

VIP/SVIP tag artwork is CDN-owned. Do **not** add these PNG files to the Flutter
asset bundle.

The Flutter client resolves the public origin through `VmApiConfig.cdnOrigin`
(`VM_CDN_BASE_URL` override; production default `https://cdn.funkey.com`).

## VIP

Publish levels 1–50 using this versioned object-key pattern:

```text
ui/vip/tags/v1/vip_tag_lv_01.png
...
ui/vip/tags/v1/vip_tag_lv_50.png
```

## SVIP

Publish levels 1–10 using:

```text
ui/svip/tags/v1/svip_tag_lv_01.png
...
ui/svip/tags/v1/svip_tag_lv_10.png
```

`frontend/vibematch_app/lib/core/assets/vip_svip_tag_assets.dart` constructs
these CDN URLs. Replace artwork by publishing a new versioned path and changing
the resolver/version deliberately; do not overwrite immutable versioned objects
in place and do not restore local Flutter asset fallbacks.
