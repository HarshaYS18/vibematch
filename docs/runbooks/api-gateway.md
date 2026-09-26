# API Gateway / edge runbook

## Scope

Use this runbook for Envoy Gateway listener/route rejection, TLS failures, gateway 5xx/429/413 spikes, WebSocket upgrade failures, WAF-origin failures, or bad canary routing.

## First checks

1. Check provider CDN/WAF/DDoS and DNS health for all four public hostnames.
2. Check `GatewayClass/funkey-envoy` Accepted status.
3. Check `Gateway/funkey-public` Programmed/Ready status and listener conditions.
4. Check `HTTPRoute/funkey-api`, `funkey-realtime`, and `funkey-media-control` Accepted/ResolvedRefs status.
5. Check Envoy Gateway controller and managed Envoy proxy pods/services.
6. Check TLS Secrets `funkey-api-tls`, `funkey-realtime-tls`, `funkey-media-tls` for expiry/mismatch without printing private data.

## Symptom actions

For widespread 404/503, compare the running route spec with the Git revision and verify backend Service endpoints. Never publish a backend Service directly as a temporary public workaround.

For 429 spikes, inspect gateway rate-limit metrics and backend saturation before raising limits. Application rate limits still apply.

For 413 spikes, confirm the request should traverse the API/media-control gateway. Large media should use signed direct object-store upload. Do not add request buffering to WebSocket routes.

For realtime disconnects, verify `/ws` resolves to `funkey-realtime`, the HTTPRoute has zero request/backend timeout, and the client idle timeout exceeds heartbeat cadence.

For canary errors, immediately return route weights to 100 stable / 0 canary. Do not delete stable pods first.

For WAF-origin failure, restore the provider edge binding; do not bypass WAF by exposing the Envoy LoadBalancer or internal Service DNS to clients.

## Validation after recovery

Verify API health/authenticated reads, one WebSocket connect/reconnect, media discovery followed by real producer-to-consumer audio, CDN object delivery, and that `X-Request-ID` is present in backend request logging/traces.

## Escalation evidence

Capture Gateway/HTTPRoute policy status, Envoy controller/proxy version, public DNS/certificate metadata, WAF policy revision, route weights, backend endpoint counts, 4xx/5xx/latency metrics, and the deployed Git/image revision.
