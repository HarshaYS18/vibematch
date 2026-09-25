# FunKey Kubernetes deployment

`base/` deploys the Python control plane, extracted domain services, Go realtime gateway, and Python JetStream worker. `gateway/` is the Chunk 35 Kubernetes Gateway API edge for Envoy Gateway and is included by staging/production overlays; local development continues to use direct loopback ports. `overlays/local`, `overlays/staging`, and `overlays/production` set environment configuration. `media/` is an opt-in deployment for the canonical `backend_media/` implementation; it must only be applied after the node networking and drain prerequisites below are verified. `jobs/migrate.yaml` is a release gate, not a continuously reconciled Job.

## Required bindings before staging or production

Replace every `example.invalid` endpoint and `:dev` image with actual immutable image digests. Provide `funkey-api-secrets` from an external secret manager with `database_url`, `redis_url`, `JWT_SECRET_KEY`, `MEDIA_INTERNAL_TOKEN`, `REALTIME_CAPABILITY_PRIVATE_KEY_B64` (a dedicated base64url-encoded 32-byte Ed25519 seed), S3 credentials, and provider credentials that the enabled features need. Provide `funkey-inbox-secrets` separately with `INBOX_DATABASE_URL`, the shared strong `INBOX_INTERNAL_TOKEN`, JWT verification configuration required by the current identity contract, Inbox backup encryption/OAuth settings when enabled, and any other Inbox-only secrets. The same `INBOX_INTERNAL_TOKEN` is also present in `funkey-api-secrets`; never place it in a ConfigMap. The realtime capability private key is API-only; never mount or copy it into the Go gateway. Production must set `MEDIA_STORAGE_DRIVER=s3` and a real CDN URL. Supply `funkey-realtime-secrets` only if the gateway requires separate secret configuration. Never store these values in Git or a ConfigMap.

Install compatible Gateway API CRDs plus a supported Envoy Gateway release, metrics-server, Prometheus adapter for custom HPA metrics, KEDA, and a Prometheus/OpenTelemetry collector. Provision the Gateway TLS Secrets documented in `gateway/README.md`, bind public DNS to the Envoy data-plane address, and keep `cdn.funkey.com` on the provider CDN/WAF edge rather than routing static bytes through Kubernetes. The API HPA uses CPU plus `funkey_http_inflight_requests`; realtime uses CPU plus `funkey_websocket_connections`. KEDA reads the `FUNKEY_EVENTS` / `funkey-worker` JetStream consumer via NATS monitoring port 8222. Configure the monitoring endpoint so KEDA can reach it without exposing it publicly. Queue age, reconnects, message rate, backpressure, and p95 latency are alert and scaling review signals; CPU is not the sole capacity measure.

Set up autoscaled node pools for system, application/worker, realtime, and media workloads. The provider's node autoscaler must add nodes for pending pods and cordon/drain safe idle nodes. Label media nodes `funkey.io/workload=media` and taint them `funkey.io/media=true:NoSchedule`. Media uses host networking and ports 4100/TCP plus 40000–49999/UDP. One media pod is scheduled per node. `status.hostIP` must be reachable by clients as both signaling and announced WebRTC IP in the supplied media manifest; if the cloud uses private node IPs or TLS termination, adapt the media public address and routing before applying. Use a separate L4/UDP or per-node WebRTC path, not normal HTTP ingress for RTP. Preserve `infra/turn/` for relay connectivity.

The media HPA is bundled only in the opt-in media overlay. Before enabling it, expose custom `funkey_media_peers` and `funkey_media_rooms` metrics through the adapter and verify scale-in on disposable rooms. `preStop` calls loopback `/drain`, waits until `peerCount` reaches zero or 300 seconds, then lets SIGTERM finish. The media service must mark itself draining in the existing FastAPI/Redis registry, reject new joins, and remain alive for assigned rooms during that window. A deadline can still end long lived calls; choose it from measured session duration and run the drain procedure before planned scale-in. Never use a plain pod delete as the regular media scale-in method.

## Release order

1. Build, test, scan, and publish digest-addressed images. Update images in the environment overlay by digest; review the resulting manifest diff.
2. Verify managed PostgreSQL backup and PITR, Redis single-primary failover, JetStream durability, object storage, all four public DNS names/TLS, Envoy Gateway route/policy status, provider WAF, and metrics adapter health.
3. Run `jobs/migrate.yaml` once as the expand migration gate and verify Alembic is at head. Do not run destructive drops automatically.
4. Apply staging overlay; run API, gateway, worker, media discovery and real WebRTC smoke tests. Observe at least one drain and reconnect.
5. Apply production overlay in a canary/progressive rollout, monitor SLO burn, then increase traffic. Halt and roll back image digest on failure; keep compatible expanded schema until old code is retired.

Chunk 35 removes the NGINX Ingress resources. Envoy Gateway now terminates API/realtime/media-control TLS, generates request IDs, applies rate and non-streaming payload limits, provides versioned service routing and a zero-weight canary backend, and sets route/client timeouts. The provider CDN/WAF/DDoS layer remains upstream and owns `cdn.funkey.com`; optional Envoy external authorization is documented in `gateway/security-policy.example.yaml` and must not replace application business authorization. Kubernetes readiness removes unhealthy endpoints; liveness only measures process health. Use `kubectl kustomize deploy/kubernetes/overlays/production` to review render output.

## Connection budget

Use the Terraform preflight contract to enforce `api_max_pods × api_pool_per_pod + inbox_max_pods × inbox_pool_per_pod + vibes_max_pods × vibes_pool_per_pod + room_control_max_pods × room_control_pool_per_pod + worker_max_pods × worker_pool_per_pod + reserved_connections <= database_max_connections`. Reserve migrations, admin, monitoring, and failover capacity. Match actual Python pool settings and HPA maxima before deployment; PgBouncer or a managed pooler is recommended at scale.


## Chunk 24 Vibes service

`funkey-vibes` is independently deployable on port 8084. The public API Gateway routes Vibes public/moderation paths directly to it while the core API keeps a rollback proxy. Bind `funkey-vibes-secrets` externally with the service-local database login, JWT validation secret, and `VIBES_INTERNAL_TOKEN`.


## Chunk 26 Room Control service

`funkey-room-control` is independently deployable on port 8085 with a 3-pod HA floor and a max of 20 replicas. It is cluster-internal in Chunk 26: the public API continues through the core compatibility proxy because paid room-theme purchase and contribution ranking are cross-domain orchestration/projection routes that remain in core.

Bind `funkey-room-control-secrets` externally with `ROOM_CONTROL_DATABASE_URL`, the strong shared `ROOM_CONTROL_INTERNAL_TOKEN`, JWT verification material required by the current identity contract, and any service-specific secrets. The same internal token is required by core for authenticated internal quote/grant/room-resolution calls. Do not put it in a ConfigMap.
