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
