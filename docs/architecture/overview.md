# Production-oriented architecture

FunKey has four independently scalable workload classes: current FastAPI business API, emerging Go realtime gateway, asynchronous workers, and canonical `backend_media` SFU. Kubernetes can manage pods and provider-supported node autoscaling; HPA, KEDA, and media capacity controllers require real metrics and a safe scale-in path. The target is evolutionary, so see the completion report for what is implemented and validated.

PostgreSQL owns durable application facts and the one Alembic schema graph. Redis/Valkey holds ephemeral fanout, presence/routing, rate limits, and media registry data. The media registry uses Lua across dynamic keys and stays on a dedicated HA single-primary service. NATS JetStream is the selected durable event broker for background work. Synchronous calls continue to enforce immediate business decisions.

The control plane authorizes each media join, assigns a healthy node, and reauthorizes sensitive signaling. The SFU only manages transport. Gateway sockets can reconnect elsewhere and fetch an authoritative snapshot; no pod-local map or load-balancer affinity can be the only source of truth.

See [ADRs](../adr/README.md), [capacity model](capacity-model.md), [deployment](deployment.md), and [module index](../MODULE_INDEX.md).
