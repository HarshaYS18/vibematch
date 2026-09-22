# ADR-006: Kubernetes orchestration

Status: Accepted architectural direction (implementation status is tracked separately)

## Context

API requests, long-lived sockets, workers, and SFU nodes have different scaling and network requirements.

## Decision

Use separately deployed API, gateway, worker, and media workloads. HPA and KEDA can add/remove pods using suitable metrics; a node autoscaler adds/removes worker VMs where the provider supports it. Use probes, disruption budgets, spread, and bounded drain hooks.

## Consequences

Manifests are defaults, not evidence of one-million-user capacity. Media needs suitable UDP/TCP networking and node pools; scale-in must honor room drain.

## Validation and change criteria

Use measured capacity stages and connection budgets before raising maxima. Keep cloud provider choice and credentials external.
