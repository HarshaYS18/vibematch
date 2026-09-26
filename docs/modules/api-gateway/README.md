# API Gateway Module

## Purpose

Provide the single public dynamic L7 boundary for FunKey using Kubernetes Gateway API and Envoy Gateway.

## Owns

TLS listeners, HTTP/WebSocket routing, edge request IDs, client/route timeouts, local gateway rate limits, non-streaming payload limits, canary traffic weights, and integration contracts for provider WAF and optional external authorization.

## Does not own

Business authentication/authorization, durable data, media-node assignment, WebRTC RTP, TURN, CDN bytes, or any internal service lifecycle.

## Source files

The deployable manifests and their per-file responsibilities are documented in `deploy/kubernetes/gateway/README.md`. Terraform supplies provider DNS/WAF bindings. Flutter consumes only the four public endpoint contracts.

## Change checklist

When adding a public route: identify the owning backend, choose an explicit public hostname/path, set a bounded timeout, decide whether request buffering is safe, define rate-limit behavior, preserve request IDs, update the architecture guard and runbook, and never expose an internal Kubernetes hostname to Flutter.
