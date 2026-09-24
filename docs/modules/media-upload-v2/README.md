# Media upload v2

## Purpose

Own the upload-session and derivative-processing lifecycle for user media without proxying large file bodies through the application API.

## Authority

PostgreSQL tables `media_upload_sessions`, `cdn_media_assets` processing columns and `cdn_media_variants` are durable control-plane truth. Object storage/CDN stores bytes and is never business authority.

## Contracts

Public control-plane endpoints are under `/api/v1/media/upload-sessions` and `/api/v1/media/{media_id}/status`. Durable worker contracts are `media.uploaded`, `media.upload.abort.requested`, `media.moderation.requested` and `media.delete.requested`.

## Upload modes

Production S3-compatible storage uses presigned single PUT or multipart URLs. Local development streams request chunks to disk. Completion verifies the object before publication.

## Processing

Images: WebP 64/128/256/512/1024. Video: poster + fMP4 HLS renditions 360/540/720 where supported. Processing is in the media worker using temporary disk; Flutter does not transcode media.

## Moderation

Moderation runs asynchronously after processing. Video moderation uses the generated poster when available. Pending profile/cover media is not activated until approved.

## Cleanup

Maintenance expires abandoned upload sessions and emits a retryable abort/delete event. Physical cleanup is handled by the media pool with normal JetStream retry/DLQ semantics.

## Client

Flutter uses the foundation streaming upload transport. Large file paths use range streams rather than whole-file reads. Interactive crop encoding uses a background isolate through `compute()`.

## Operations

See `docs/runbooks/media-v2-upload.md` and `docs/architecture/media-v2-upload.md`.
