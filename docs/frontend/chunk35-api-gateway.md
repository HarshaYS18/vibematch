# Chunk 35 — API Gateway

**Status: COMPLETE.**

## Goal

Replace the legacy Kubernetes Ingress boundary with Kubernetes Gateway API implemented by Envoy Gateway, while keeping all durable/domain authority in the existing services.

## Public endpoints

- `api.funkey.com` — REST/control-plane API.
- `realtime.funkey.com` — sole application WebSocket.
- `media.funkey.com` — stable media control/discovery alias.
- `cdn.funkey.com` — provider CDN/WAF edge for static/media delivery.

Flutter never discovers Kubernetes service names.

## Implemented controls

The gateway owns routing, request-ID generation, local edge rate limiting, API-version routing, zero-weight canary routing, request/backend/client timeouts, API/media-control payload limits, TLS termination, and integration points for upstream WAF/DDoS plus optional Envoy external authorization.

WebSocket traffic is deliberately not request-buffered. The media L7 alias does not replace sticky SFU assignment, node signaling, RTP, or TURN.

## Canary contract

The stable API Deployment/Service is labeled `funkey.io/release-track=stable`; `funkey-api-canary` selects only canary pods. HTTPRoute begins at 100/0. Canary traffic may be raised only after ready canary endpoints exist.

## Security model

The provider WAF/DDoS policy protects the Envoy origin. Envoy strips spoofable internal trust headers, generates request IDs, terminates public TLS, and may optionally call a real external-auth service through the documented `SecurityPolicy`. Backend application authorization remains authoritative.

## Acceptance evidence

- legacy NGINX Ingress removed from reconciled manifests;
- production/staging Kustomize overlays include the Gateway module;
- production public DNS names are pinned by Terraform preconditions;
- Flutter production endpoint constants use only public origins;
- architecture guards reject internal service discovery;
- Production Platform CI renders gateway/staging/production manifests and runs `scripts/check_gateway_architecture.py`.

## Documentation map

Every new gateway manifest is described by `deploy/kubernetes/gateway/README.md`. Architecture is documented in `docs/architecture/api-gateway.md`; operations in `docs/runbooks/api-gateway.md`; module ownership in `docs/modules/api-gateway/README.md`.


## Repair audit: canary isolation and CI correctness

The post-Chunk-35 anomaly audit closed two defects:

- the Watch Party source-of-truth test now checks for a real repository import
  rather than failing on an architecture comment that merely names the
  repository class;
- the stable API workload is now `funkey-api-stable` with an isolated
  stable-track selector. The HPA, topology spread and PDB target stable pods
  only, so future canary pods cannot overlap the stable Deployment controller.

The workload rename is deliberately migration-safe and avoids an in-place
immutable Deployment-selector mutation.
