# Flutter canonical networking — Chunk 32

All application REST/control-plane traffic converges on:

`Repository / feature service -> AppNetworkClient -> CanonicalNetworkTransport -> Dio`.

Feature directories may not instantiate or import `package:http`, `package:dio`, or raw `HttpClient`. A temporary foundation compatibility facade preserves the existing `http.get/post/Response/MultipartRequest` call shape while routing those calls through the same shared Dio transport. It is a migration seam, not a second client.

The canonical transport owns connect/receive/send timeouts, request IDs, W3C traceparent headers, bearer-token injection, a single-flight refresh hook, cancellation, idempotency headers, bounded retry of safe/idempotent operations, normalized `ApiException` failures, connection reuse, and low-cardinality request counters/latency metrics.

Signed object-store upload and remote untrusted asset retrieval remain specialized foundation transports; feature code does not own them.
