# API Gateway Architecture

## Ownership

The API Gateway is transport/security infrastructure. It owns public L7 routing, TLS listener configuration, edge request metadata and traffic protection policies. It does not own identity, authorization decisions, rooms, Inbox, Vibes, Economy, games, media assignment, or any durable state.

## Topology

```text
Internet
  -> provider CDN / WAF / DDoS
       -> api.funkey.com       -> Envoy Gateway -> API/domain Services
       -> realtime.funkey.com  -> Envoy Gateway -> Go realtime
       -> media.funkey.com     -> Envoy Gateway -> media control/discovery
       -> cdn.funkey.com       -> provider CDN/object origin

Room media discovery -> assigned public SFU / TURN
```

Static CDN traffic intentionally does not hair-pin through Kubernetes.

## Gateway API resources

`funkey-envoy` is the GatewayClass. `funkey-public` has separate HTTPS listeners for API, realtime, and media-control traffic. HTTPRoutes attach by listener section, preventing hostname/path rules from bleeding across public surfaces.

Envoy `ClientTrafficPolicy` generates a fresh request ID at the edge and applies client receive/idle timeouts. `BackendTrafficPolicy` adds local rate limits and bounded request buffering only to non-streaming routes.

## API routing

More-specific v1 routes send Vibes and Inbox traffic directly to their owning services. Other v1 and compatibility paths use core. The stable/core fallback has 100/0 weighted stable/canary backends.

## Edge authentication and WAF

Application authorization is always authoritative. Edge auth is optional defense in depth using Envoy `SecurityPolicy` after a real ext-auth service is deployed. Client-supplied internal trust headers are stripped before routing.

The provider WAF/DDoS layer is mandatory in production and is represented by the Terraform `waf_policy_ref` binding. Provider-specific WAF credentials and rules are intentionally not stored in Git.

## Media boundary

`media.funkey.com` is L7 control/discovery only. The existing backend media registry remains authoritative for node assignment. Envoy does not load-balance RTP across arbitrary media pods and does not replace TURN.

## Failure behavior

If Envoy is unavailable, public dynamic traffic fails closed; internal services do not become directly public. If WAF/CDN is unavailable, do not bypass it by publishing cluster Service addresses. If canary has no ready endpoints, keep its route weight at zero.

## Evolution

Chunk 36 may attach the GraphQL Read BFF behind this gateway. New services must add route ownership explicitly; Flutter must continue using public endpoints rather than service discovery.
