# FunKey API Gateway — Chunk 35

This directory is the Kubernetes Gateway API boundary for FunKey's public
dynamic traffic. Envoy Gateway is the approved implementation.

## File map

- `gateway-class.yaml` — declares the Envoy Gateway controller contract.
- `gateway.yaml` — TLS listeners for `api.funkey.com`,
  `realtime.funkey.com`, and `media.funkey.com`.
- `routes.yaml` — API-version/service routing, WebSocket routing, media-control
  routing, request/backend timeouts, and the stable/canary traffic split.
- `policies.yaml` — request-ID generation, client receive/idle timeouts,
  spoofable internal-header stripping, local edge rate limits, and bounded
  non-streaming request payloads.
- `canary-service.yaml` — zero-traffic canary Service target. It receives no
  traffic until operators deploy pods labeled `funkey.io/release-track=canary`
  and deliberately change HTTPRoute weights.
- `security-policy.example.yaml` — optional Envoy `SecurityPolicy` ext-auth
  integration. It is intentionally not reconciled until a real edge-auth
  service exists; application authorization remains authoritative.
- `kustomization.yaml` — the production/staging gateway resource set.

## Public endpoint contract

`api.funkey.com` is the versioned REST/control plane.
`realtime.funkey.com/ws` is the sole application WebSocket.
`media.funkey.com` is the stable L7 media-control/discovery alias; room media
still returns an assigned public mediasoup node or TURN route and never exposes
a Kubernetes service name.

`cdn.funkey.com` is intentionally terminated by the global CDN/WAF layer
before Kubernetes. Static bytes must not hair-pin through Envoy. Terraform and
the deployment/runbook documentation still require this public hostname.

## Security and traffic behavior

Envoy generates a fresh `X-Request-ID` at the edge and strips client-supplied
internal trust headers before routing. API and media-control requests have body
limits; WebSocket traffic does not use request buffering because buffering is
incompatible with upgrades/streaming.

Local rate limits are an early overload/abuse guard; application/domain rate
limits remain authoritative. The upstream provider WAF/DDoS service is required
in production. Optional Envoy ext-auth is defense in depth and must never become
the sole business authorization layer.

## Canary procedure

The stable Service selects `funkey.io/release-track=stable`; the canary
Service selects `funkey.io/release-track=canary`. The route starts at
100/0. Deploy and verify canary endpoints first, then raise the canary weight in
small reviewed steps. Never set a non-zero canary weight while the canary
Service has zero ready endpoints.

## Certificates

External secret/certificate automation must create `funkey-api-tls`,
`funkey-realtime-tls`, and `funkey-media-tls` in namespace `funkey`.
No private keys are stored in Git.


## Stable/canary selector isolation

The stable API workload is `Deployment/funkey-api-stable`. Its immutable
selector includes both `app=funkey-api` and
`funkey.io/release-track=stable`; HPA, topology-spread constraints and PDB
scope only stable pods. The public Service remains `funkey-api`.

A future canary Deployment must use `funkey.io/release-track=canary` and must
not overlap the stable Deployment selector.

For an existing cluster with the legacy `Deployment/funkey-api`, apply the
new stable Deployment first, wait for ready `Service/funkey-api` endpoints,
then let GitOps prune the legacy Deployment. Do not mutate the old Deployment
selector in place because Kubernetes Deployment selectors are immutable.


## Pinned controller and CRD compatibility

Chunk 35 is pinned to:

- Envoy Gateway `v1.9.1`;
- Gateway API `v1.6.1` standard channel;
- Kubernetes `v1.36.4` for CI server-side schema validation;
- kind `v0.33.0` with the pinned Kubernetes 1.36.4 node-image digest.

The authoritative pins live in `VERSIONS.env`. Do not use `latest` in
production install commands.

`install-envoy-gateway.sh` installs the pinned Gateway API + Envoy CRDs first,
verifies the Gateway API bundle annotation, then installs the pinned Envoy
Gateway chart with chart-managed CRDs disabled.

CI creates an ephemeral pinned kind cluster, installs the same CRDs, and runs
server-side dry-run against the rendered Gateway resources and optional
SecurityPolicy example. Plain `kubectl kustomize` rendering is retained but is
not considered sufficient schema validation.
