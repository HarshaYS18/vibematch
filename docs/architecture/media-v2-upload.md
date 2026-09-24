# Media v2 upload and processing architecture

Chunk 31 replaces large API-proxied media uploads with an upload-session control plane and direct object-store data plane. Existing UI surfaces remain unchanged.

## Flow

1. Flutter creates an authenticated `/api/v1/media/upload-sessions` session with purpose, filename, MIME type and declared byte length.
2. Production returns either a presigned single PUT or a bounded multipart plan. Local development returns a streamed local endpoint.
3. Flutter streams file ranges directly; it does not buffer large video/audio files into memory.
4. `/complete` finalizes multipart state when needed, HEADs the object, verifies exact size and declared content type, and only then changes the asset to `PROCESSING`.
5. The same transaction enqueues `media.uploaded` through the PostgreSQL outbox.
6. The media worker downloads to bounded temporary disk, creates derivatives, persists variant metadata, and only then emits moderation work when required.
7. The client polls owner-scoped status until the media becomes usable or reaches a terminal failure/review state.

## Processing products

Images generate WebP widths 64, 128, 256, 512 and 1024. Video creates a WebP poster and fMP4 HLS/CMAF-style renditions at 360p, 540p and 720p when the source supports those heights, plus a master playlist.

PostgreSQL owns upload sessions, processing state and variant metadata. Object storage/CDN owns bytes only. Remote clients never decide moderation, processing or durable media state.

## Abandoned uploads

The maintenance worker periodically expires CREATED/UPLOADING sessions using `FOR UPDATE SKIP LOCKED`. Expiration enqueues `media.upload.abort.requested`; the media worker aborts multipart state and removes the object through the normal retry/DLQ path. `NoSuchUpload` is idempotent success.

## Client memory rules

Large Vibes/video and room-music paths use `XFile.openRead` and streamed PUTs. Interactive image crop flows may hold their picker-downscaled image in memory for preview/crop; JPEG crop encoding runs in `compute()`, not the UI isolate.

## Failure rules

No source event is acknowledged before processing succeeds. Failed derivative generation ends in `PROCESSING_FAILED` and is retryable through JetStream delivery. Moderation occurs after derivatives so video moderation can use the generated poster. Completion verification failure marks the asset rejected and schedules deletion.
