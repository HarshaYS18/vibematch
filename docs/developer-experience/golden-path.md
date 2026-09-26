# Developer golden path

The supported local path is intentionally boring:

```text
git clone
  -> make bootstrap
  -> make dev
  -> make seed
  -> edit/test
  -> make test
  -> make lint
  -> make down
```

`make bootstrap` checks core tools, creates untracked env files from examples,
installs backend dependencies and, when installed, media/Flutter dependencies.
It does not create production credentials.

`make seed` applies migrations through the normal local stack and then runs the
idempotent development seed. The seed hard-fails outside dev/local/test and
requires an explicit confirmation environment variable. Seed wallets are zero
value; no fake Economy ledger/supply is created.

For a new deployable, use:

```text
make scaffold-service NAME=my-service
```

The generator creates health/readiness/metrics endpoints, OTel dependencies,
tests, Dockerfile, hardened Kubernetes skeleton, README, runbook and CODEOWNERS
entry. It does **not** grant durable state ownership; authority changes still
require RFC/ADR review.
