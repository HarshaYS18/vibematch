# Inbox

## Purpose

The Inbox Service is the exclusive durable authority for chat conversations, participants, messages, read receipts, unread counters, per-user mute/pin/archive state, chat preferences, Inbox reports/locks/backups, and Inbox call sessions.

## Deployable

Production deployable: `apps/inbox-service/` (`funkey-inbox`).

The core API does not mount Inbox chat implementation routes. It retains a compatibility proxy for rollback/local development, while production ingress routes Inbox paths directly to `funkey-inbox`.

Stories remain on the social/core boundary until the later Vibes/Profile ownership chunks.

## Source of truth

PostgreSQL is durable authority. The production Inbox login is a member of `funkey_inbox_runtime`; the owned tables are held by the NOLOGIN `funkey_inbox_owner` role. See `deploy/postgres/inbox-ownership.sql`.

Redis is only ephemeral presence/transport state. NATS carries transient realtime delivery to the Go application gateway; loss of a realtime event is recovered by refetching bounded REST state.

## Read contract

- conversation lists use keyset cursors;
- conversation list payloads are summary-only and contain no message history;
- opening a conversation fetches a bounded active message window;
- older messages use a message cursor;
- ordinary GETs do not bootstrap, repair, mark-read, reopen Secret Drift, or otherwise mutate state;
- read receipts use explicit mutation commands/endpoints.

The active chat message window defaults to 50 and public page sizes are capped at 100. Conversation-list pages use only a last-message summary row for preview and serialize an empty `messages` array for compatibility.

## Realtime

The write path is:

`Inbox commit -> NATS subject funkey.events.inbox.realtime -> Go realtime gateway -> connected clients`.

Socket commands such as typing/activity/read travel:

`Flutter -> one Go application socket -> Inbox realtime command endpoint`.

Go owns transport only. It never owns Inbox persistence.

## Internal service boundary

Other domains must not import Inbox ORM models to write them. They use the authenticated internal Inbox API through `backend/app/services/inbox_service_client.py`. The shared `INBOX_INTERNAL_TOKEN` is supplied by the secret manager to core and Inbox workloads; it is never stored in Git.

Current adapters cover family chat, Vibe mention messages, media-expiry placeholders, media-safety team messages, and relationship-card messages.

## Database ownership

Owned tables:

- inbox_conversations
- inbox_participants
- inbox_messages
- inbox_read_receipts
- inbox_reports
- inbox_lock_settings / inbox_lock_otps
- inbox_user_preferences
- inbox_conversation_user_settings
- inbox_message_user_states
- inbox_backup_settings / inbox_backup_jobs
- call_sessions / call_participants

The Inbox runtime receives read-only access to identity context needed to authenticate and render users. It does not own users or roles.

## Failure behavior

If realtime delivery is missed, clients recover via REST cursors. If the Inbox service is unavailable, core adapters return a bounded failure or keep the already-committed owning-domain state and rely on later reconciliation; they must never fall back to direct Inbox table writes.

## Deployment

1. Apply Alembic through revision `20260923_0310` or later.
2. Run `deploy/postgres/inbox-ownership.sql` with an administrative/migration role.
3. Provision a production Inbox login externally and grant it `funkey_inbox_runtime`.
4. Put `INBOX_DATABASE_URL` only in `funkey-inbox-secrets`.
5. Put the same strong `INBOX_INTERNAL_TOKEN` in core API and Inbox secrets.
6. Configure NATS and Go realtime Inbox subject/command routes.
7. Deploy Inbox before moving ingress traffic.
8. Verify `/live`, `/ready`, cursor reads, send/read flows, NATS fanout, and rollback proxy.

## Important files

- `apps/inbox-service/main.py`
- `apps/inbox-service/database.py`
- `apps/inbox-service/internal.py`
- `apps/inbox-service/realtime.py`
- `backend/app/services/inbox_service.py`
- `backend/app/api/routes/inbox.py`
- `backend/app/api/routes/inbox_proxy.py`
- `deploy/postgres/inbox-ownership.sql`
- `docs/architecture/inbox-service.md`

## Change checklist

Preserve one durable writer, bounded reads, explicit mutation endpoints, backward-compatible public response fields, NATS -> Go delivery, and service-local DB credentials. Any new cross-domain Inbox write requires a service contract rather than a shared ORM import.


## Flutter call-camera resource lifecycle

Chunk 34-M12 registers the concrete local video-call camera through the
foundation `MediaResourceRegistry`.

`InboxCallMediaBridge` remains the owner of the call `MediaStream`, mediasoup
producers and transport. Backgrounding pauses the camera without ending call
audio; foreground resumes only if lifecycle paused it. Session teardown stops
the video producer/track. Durable Inbox call sessions and participants remain
Inbox-service/PostgreSQL authority.
