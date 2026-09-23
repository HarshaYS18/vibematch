# FunKey Inbox Service

Chunk 23 extracts durable Inbox authority from the core API without changing the public mobile/web API surface.

## Owns

- conversations and participants
- messages and read receipts
- unread counters
- per-user mute, pin and archive state
- per-conversation chat presentation settings
- Inbox calls, message tools, search/AI and backup operations that read or mutate Inbox-owned tables

PostgreSQL is the durable authority. INBOX_DATABASE_URL must use a dedicated production login. The role owns Inbox tables and receives only explicitly documented compatibility reads for identity/profile data while those domains remain in the core schema.

## Public routing

The service serves the existing /api/v1/inbox/**, /api/v1/inbox-ai/** and /api/v1/calls/** paths.

Production ingress routes those prefixes directly here. The core API keeps a bounded compatibility proxy for rollback/local development; it must not write Inbox tables.

## Read contract

Conversation and message history endpoints use keyset/cursor pagination. The active conversation payload contains a bounded message window only. Ordinary GET requests never bootstrap conversations, merge duplicates, mark messages read or change Secret Drift state.

## Realtime

Inbox business state commits here. Realtime delivery is published to NATS on funkey.events.inbox.realtime; the Go application realtime gateway consumes that subject and performs user fanout. Redis remains presence/transport projection only.

## Required production settings

INBOX_DATABASE_URL, INBOX_SERVICE_URL, INBOX_REALTIME_TRANSPORT=nats, NATS_URL, and INBOX_NATS_SUBJECT are supplied externally. No production credential belongs in this repository.
