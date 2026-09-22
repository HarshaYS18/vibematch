# Worker-node autoscaling strategy

Kubernetes HPA and KEDA create or remove pods. They do not create virtual machines. A provider-supported cluster/node autoscaler must observe pending pods and provision suitable worker capacity. On scale-in it must cordon and drain an unused safe node, obey disruption budgets, and respect gateway/media drain windows before removing the VM.

Keep separate scheduling pools for system services, API/workers, realtime gateways, and media SFUs. Media nodes need enough network throughput, public/announced addressing, UDP/TCP port range, and TURN reachability. Do not allow an API scale event to evict active media rooms. Use topology spread and capacity in multiple zones where the selected provider offers it.

External setup needs cloud credentials, node quota, subnets/IP capacity, image registry access, autoscaler installation, and per-pool min/max sizes. This repository can supply pod requests, affinities, disruption budgets, and example node labels. Exact VM SKU and pool limits must be chosen from measured CPU, memory, bandwidth, packet rate, and cost. A pending pod during a drill should cause a node to join within an acceptable delay; a drained idle node should later disappear without breaching the service minimum.

Before increasing HPA/KEDA maxima, recheck PostgreSQL connections, NATS/Redis capacity, ingress and TURN limits. Autoscaling a bottlenecked application into a saturated database makes the incident worse.
