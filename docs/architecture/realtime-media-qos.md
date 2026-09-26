# Realtime / media QoS architecture

Chunk 45 keeps the single Go application WebSocket and canonical mediasoup media
plane. It adds explicit QoS budgets and hot-room observability rather than a
second transport.

Realtime fanout is already horizontally distributed because each gateway owns
only its local sockets while Redis/NATS deliver the event to replicas. Inside a
gateway, users/rooms use 32 route shards and priority queues. A room becomes
"hot" at 500 local subscribers; metrics expose hot-room count and maximum local
room fanout so HPA/capacity alerts can react before one node saturates.

Media nodes expose hot-room/max-peer metrics and join-latency histograms. Initial
outgoing bitrate is configurable and UDP remains preferred with TURN fallback.

Critical control events may evict lower-priority traffic but must not be silently
dropped. Best-effort presence/animation traffic may be dropped under pressure.
