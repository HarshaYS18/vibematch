# Service Contracts

**Owner:** Platform Architecture  
**Status:** Chunk 17 contract-before-extraction policy

## Purpose

FunKey defines service boundaries before physically extracting services. The contract source of truth is `contracts/proto/` for synchronous internal service contracts and `contracts/events/` for asynchronous event envelopes.

Chunk 17 does **not** move tables or create new service authorities. It creates versioned interfaces that later extraction chunks must implement while preserving the Chunk 15 authority registry.

## Contract rules

- Protobuf packages are versioned: `funkey.<domain>.v1`.
- Never reuse a removed field number.
- Never change the meaning of an existing field in place.
- Additive fields are preferred.
- Breaking changes require a new package version.
- Internal service methods use gRPC after extraction; REST remains the compatibility/public edge where already used.
- GraphQL is not introduced here and will remain a composite-read layer later.
- Domain events continue through the transactional outbox and NATS JetStream.
- Protobuf/gRPC schemas do not become business authority; the owning service/database remains authoritative.

## Metadata

Every internal request that can be traced or audited carries `RequestContext` with request ID, W3C traceparent, actor identity when known, and idempotency key when the operation is replay-sensitive.

Do not put bearer tokens, passwords, OTPs, payment secrets, private message bodies, or arbitrary user content in metadata.

## Initial logical service contracts

- Identity: session/user lookup and authorization facts.
- Profile/Social: public profile and relationship reads.
- Room Control: room snapshot, membership/permission checks, and room commands.
- Inbox: conversation/message commands and reads.
- Vibes: feed/content read seams.
- Economy: wallet read and value-transfer command seam.
- Game Platform: game/round lifecycle and settlement request seam.
- Notification: enqueue notification delivery request.
- Media Control: media authorization/asset metadata seam.

These contracts are migration seams. Existing FastAPI behavior remains compatible until the later extraction chunks cut traffic over.

## Compatibility strategy

For each extracted service:

1. define/add contract;
2. generate clients;
3. implement adapter behind existing REST/event behavior;
4. mirror/shadow where needed;
5. compare results;
6. canary internal traffic;
7. cut over callers;
8. keep compatibility adapter during soak;
9. remove old direct-table path only after evidence is clean.

## Generated code

Generated clients are build artifacts, not hand-edited domain code. Generation must be deterministic and verified in CI. Languages required by current architecture:

- Python
- Go
- TypeScript
- Dart

Generated code lives under language-specific generated directories and must never be manually modified.

## Events

`contracts/events/` remains the asynchronous contract registry. Event compatibility rules:

- event names are stable;
- `event_version` increases only when payload semantics require it;
- consumers ignore unknown additive fields;
- publishers do not remove required fields from an active version;
- incompatible payloads require a new event version and coexistence/migration period.

## Validation gate

Chunk 17 is complete when schema linting, breaking-change detection, deterministic generation, generated-code drift checks, and representative cross-language compile/tests pass without changing business ownership.
