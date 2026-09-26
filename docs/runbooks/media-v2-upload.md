# Media v2 upload runbook

## Symptoms

Check upload-session status, asset `upload_status`/`processing_status`, worker consumer lag and the `media.uploaded` / abort / moderation DLQs separately.

## Direct upload failures

For single PUT, recreate an upload session after expiry. For multipart, never fabricate missing ETags. Completion requires exactly the planned part numbers and then verifies object size/content type. If the first completion call may have succeeded but the client saw a timeout/5xx, retry the same session and part list; `NoSuchUpload` is recoverable only when the object can be HEADed and subsequently passes the declared size/content-type checks.

## Processing failures

`PROCESSING_FAILED` means the source object completed but derivative generation failed. Inspect the media worker log for ffmpeg/Pillow/storage errors, fix the dependency, and replay the original `media.uploaded` event identity. Do not mark the asset approved manually.

## Moderation

Moderation begins only after derivative processing. Video review uses the generated poster. Human-review-required media remains unavailable until a moderation authority resolves it.

## Abandoned sessions

The maintenance worker scans expired CREATED/UPLOADING sessions every `MEDIA_UPLOAD_CLEANUP_INTERVAL_SECONDS` (default 900s), bounded by `MEDIA_UPLOAD_CLEANUP_BATCH_SIZE` (default 100). It does not delete bytes inline: it emits `media.upload.abort.requested`, which the media worker retries safely. S3 `NoSuchUpload` is treated as already cleaned.

## Storage

Production requires private S3-compatible storage and a CDN origin that can read it. Do not enable public-read merely to fix CDN access. Configure origin credentials/policy instead.

## Rollback

Keep the legacy upload endpoints only as a compatibility fallback until the Flutter rollout is fully soaked. Do not route new large-video/audio flows back through API body buffering. Rollback must preserve one durable media-state authority.
