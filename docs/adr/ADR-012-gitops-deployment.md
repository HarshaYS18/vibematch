# ADR-012: Argo CD GitOps deployment strategy

Status: Accepted architectural direction (implementation status is tracked separately)

## Context

Production rollouts need reviewable desired state and recovery from drift across multiple workloads.

## Decision

Use CI to test and publish immutable images, then promote pinned digests through versioned environment configuration reconciled by Argo CD. Migrations are a controlled pre-deploy job, not an application startup side effect. Separate staging and production promotion.

## Consequences

Cloud cluster, registry, credentials, and Argo CD installation remain external prerequisites. The repository can provide manifests and workflow hooks, but no deployment is complete until a real environment runs and validates them.

## Validation and change criteria

Rollback by restoring the prior known-good image/config digest after checking migration compatibility. Never auto-revert a destructive schema change or skip the media drain sequence.
