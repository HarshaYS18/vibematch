# Inbox Service Architecture — Chunk 23

## Decision

FunKey physically extracts chat authority into `funkey-inbox` while preserving the existing public HTTP paths and the single Go application WebSocket.

The extraction is a strangler cutover, not a UI redesign. Public clients continue to use `/api/v1/inbox/**` and `/api/v1/calls/**`.

## Ownership

Inbox owns conversations, participants, messages, read receipts, unread counts, mute/pin/archive, chat presentation settings, report/lock/backup records, and chat call sessions.

Stories are intentionally excluded from this extraction and remain on the social/core boundary pending the Vibes/Profile service work.

## Read model and pagination

Conversation list order is keyset-paged by per-user pinned state, conversation updated time, and stable numeric ID. Message history is keyset-paged by created time and ID. No endpoint may return unbounded message history.

Conversation summaries carry only an active message window so Inbox opening cannot become all-conversations multiplied by all-history.

## Mutation semantics

GET handlers are side-effect free. Official-team bootstrap, mark-read, Secret Drift open/close, state changes, and message mutations use explicit write endpoints or realtime commands.

Read receipts are explicit rows for the recent active window plus a participant last-read pointer for bounded historical state.

## Service isolation

`INBOX_DATABASE_URL` is service-local and must use a production login that is not the core API login. The runtime group has DML only on Inbox-owned tables and bounded SELECT access to identity context. Migrations remain an administrative responsibility.

Cross-domain writers call the authenticated internal Inbox API. Direct ORM writes from Families, Vibes, media cleanup, media safety, or relationship-card code are prohibited.

## Realtime

Inbox business state is committed before transient delivery. Inbox publishes the canonical Go gateway envelope to NATS. The Go gateway validates the envelope, deduplicates, applies backpressure, and fans out to users.

Redis remains the current ephemeral presence/routing substrate and compatibility event transport for domains not yet moved to NATS. It is never Inbox durable truth.

## Failure and recovery

NATS delivery is intentionally transient for Inbox realtime. Clients recover from missed events through bounded cursor reads. Service-to-service mutations use bounded timeouts and do not silently retry non-idempotent writes.

A core-domain transaction that is already committed must not reacquire direct Inbox DB access during an Inbox outage. Projection/adaptor reconciliation is safer than creating a second writer.

## Rollback

The expanded schema is backward compatible during rollout. The core API compatibility proxy can route the same public request shapes to the Inbox service. Roll back an application image or ingress change without dropping the additive read-receipt/per-user-state schema. Do not reverse the ownership migration during an incident.
