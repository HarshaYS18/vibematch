#!/usr/bin/env python3
"""Generate a production-shaped FunKey service skeleton.

This creates structure, not authority. Moving durable state into the generated
service still requires an ADR/RFC and migration plan.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def normalize_name(value: str) -> str:
    name = value.strip().lower()
    if not re.fullmatch(r"[a-z][a-z0-9-]{2,48}", name):
        raise SystemExit("service name must match [a-z][a-z0-9-]{2,48}")
    return name


def write_new(path: Path, content: str) -> None:
    if path.exists():
        raise SystemExit(f"Refusing to overwrite existing scaffold path: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("name")
    parser.add_argument("--owner", default="@HarshaYS18")
    args = parser.parse_args()
    name = normalize_name(args.name)
    app = ROOT / "apps" / f"{name}-service"
    if app.exists():
        raise SystemExit(f"Service already exists: {app.relative_to(ROOT)}")

    write_new(
        app / "main.py",
        f'''"""Generated FunKey {name} service skeleton. Define authority before adding writes."""

from fastapi import FastAPI
from fastapi.responses import PlainTextResponse

app = FastAPI(title="FunKey {name}", version="0.1.0", docs_url=None, redoc_url=None)


@app.get("/live")
def live() -> dict[str, str]:
    return {{"status": "live"}}


@app.get("/ready")
def ready() -> dict[str, str]:
    return {{"status": "ready"}}


@app.get("/metrics", response_class=PlainTextResponse)
def metrics() -> PlainTextResponse:
    return PlainTextResponse(
        "funkey_service_info{{service=\"{name}\"}} 1\\n",
        media_type="text/plain; version=0.0.4",
    )
''',
    )
    write_new(
        app / "requirements.txt",
        "fastapi==0.136.1\nuvicorn[standard]==0.46.0\n"
        "opentelemetry-api==1.44.0\n"
        "opentelemetry-sdk==1.44.0\n"
        "opentelemetry-instrumentation-fastapi==0.65b0\n",
    )
    write_new(
        app / "Dockerfile",
        f'''FROM python:3.13-slim-bookworm
WORKDIR /app
COPY apps/{name}-service/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt \
    && groupadd --system funkey \
    && useradd --system --gid funkey --home /app funkey
COPY --chown=funkey:funkey apps/{name}-service/ /app/
USER funkey
EXPOSE 8080
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
''',
    )
    write_new(
        app / "tests" / "test_health.py",
        '''import unittest
from fastapi.testclient import TestClient
from main import app

class HealthTests(unittest.TestCase):
    def test_live(self):
        self.assertEqual(TestClient(app).get("/live").status_code, 200)

if __name__ == "__main__":
    unittest.main()
''',
    )
    write_new(
        app / "README.md",
        f'''# {name} service

Generated with `scripts/scaffold_service.py`.

Before adding durable writes, copy `docs/templates/service-readme.md` sections
into this README and complete ownership/authority/security/SLO/runbook details.
The generator deliberately does not grant database ownership.
''',
    )
    write_new(
        ROOT / "deploy" / "kubernetes" / "generated" / f"{name}.yaml",
        f'''apiVersion: v1
kind: ServiceAccount
metadata: {{name: funkey-{name}}}
automountServiceAccountToken: false
---
apiVersion: apps/v1
kind: Deployment
metadata: {{name: funkey-{name}}}
spec:
  replicas: 2
  selector: {{matchLabels: {{app: funkey-{name}}}}}
  template:
    metadata: {{labels: {{app: funkey-{name}}}}}
    spec:
      serviceAccountName: funkey-{name}
      automountServiceAccountToken: false
      securityContext: {{runAsNonRoot: true, seccompProfile: {{type: RuntimeDefault}}}}
      containers:
        - name: {name}
          image: funkey-{name}:dev
          ports: [{{name: http, containerPort: 8080}}]
          readinessProbe: {{httpGet: {{path: /ready, port: http}}}}
          livenessProbe: {{httpGet: {{path: /live, port: http}}}}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities: {{drop: [ALL]}}
''',
    )
    write_new(
        ROOT / "docs" / "runbooks" / f"{name}.md",
        f'''# {name} service runbook

Generated skeleton. Document symptoms, dashboards, immediate checks, safe
mitigation, dangerous actions, recovery validation and escalation before
production promotion.
''',
    )

    codeowners = ROOT / ".github" / "CODEOWNERS"
    entry = f"/apps/{name}-service/ {args.owner}\n"
    current = codeowners.read_text(encoding="utf-8")
    if entry not in current:
        codeowners.write_text(current.rstrip() + "\n" + entry, encoding="utf-8")

    print(f"Generated {app.relative_to(ROOT)}")
    print("NEXT: add service-catalog entry + ADR/RFC if authority changes + CI image/deploy wiring.")


if __name__ == "__main__":
    main()
