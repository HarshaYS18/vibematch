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


## Dedicated media-control hostname

The media listener is intentionally narrow. `media.funkey.com` accepts only
the public media-control namespace rooted at
`/api/v1/media-control`. It is not a second alias for the general REST API.

Room-media assignment is available at
`/api/v1/media-control/rooms/{room_public_id}/assignment`. The historical
`api.funkey.com/api/v1/rooms/{room_public_id}/media` path remains registered
inside FastAPI for rollback/older clients, but new Flutter media discovery uses
the dedicated media-control origin.

Uploads, admin media routes, and internal media-node heartbeat/drain endpoints
do not become reachable through the public media hostname merely because they
share the core service process.


## Provider WAF and origin-lock contract

FunKey keeps the Terraform core provider-neutral, so it does not claim to
provision a cloud-specific WAF. Production is still fail-closed: the deployment
contract requires a real WAF policy reference, a real origin-restriction
reference, and an explicit operator attestation that both are attached.

The origin restriction is as important as the WAF itself. Public clients must
not be able to bypass the provider edge and reach the Envoy load balancer
directly. The attestation flag is intentionally false in the example variables
and must only be enabled by the provider-binding layer/operator after
verification.


## Namespace ingress isolation

The application namespace has default-deny ingress. Public HTTP/WebSocket
backends admit the Envoy data-plane namespace, same-namespace service traffic,
and namespaces explicitly labeled for observability. Internal-only services do
not admit Envoy directly.

This replaces the original empty `namespaceSelector`, which effectively
trusted all namespaces and undermined the gateway boundary.
