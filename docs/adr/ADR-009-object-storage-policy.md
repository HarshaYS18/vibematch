# ADR-009: Object storage and CDN policy

Status: Accepted architectural direction (implementation status is tracked separately)

## Context

Application pod disks are ephemeral and cannot hold permanent avatars, covers, attachments, recordings, or exports.

## Decision

Use the existing media storage abstraction with S3-compatible storage and CDN/object URLs in production. Local filesystem is development/test only. Prefer signed uploads or bounded server uploads with content validation and metadata ownership checks.

## Consequences

Requires bucket, endpoint, credentials, CDN, retention, and lifecycle policy from the deployment owner. Private media must not be exposed by a public URL merely because a key exists.

## Validation and change criteria

Verify upload, read, deletion, and outage behavior in staging; never rely on local pod files for recovery.
