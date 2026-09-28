# SLO / error-budget runbook

When a fast/slow burn alert fires, identify the owning SLI and dependency before
changing thresholds. If the 28-day error budget is exhausted, freeze
non-essential releases and prioritize reliability recovery.

Do not hide errors with retries that amplify load, exclude slow operations from
metrics, or widen latency thresholds without an approved SLO change.

Resume normal release pace only after the owner records the incident, validates
the repaired path and error-budget burn returns to an acceptable trajectory.
