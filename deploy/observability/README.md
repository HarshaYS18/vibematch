# FunKey observability package

This directory contains provider-neutral Prometheus alert rules and a Grafana dashboard ConfigMap for the production control plane, realtime gateway, worker, and media nodes.

The rules assume Prometheus Operator CRDs and a Grafana sidecar that discovers ConfigMaps labeled `grafana_dashboard=1`. Those components are infrastructure prerequisites; they are intentionally not installed by the application repository.

Initial operational objectives are API 5xx below 1% over ten minutes, API p95 below one second, healthy realtime Redis subscriptions, no sustained capacity rejection, no dead-letter growth, and healthy media registry connectivity. Treat these as starting guardrails rather than measured capacity claims. Tune them only from staging/load-test evidence and record the change in the production audit.

Render with:

```sh
kubectl kustomize deploy/observability
```
