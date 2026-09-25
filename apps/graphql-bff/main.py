"""FunKey read-only GraphQL BFF with persisted-operation SLO instrumentation."""

from __future__ import annotations

import inspect
import json
from contextlib import asynccontextmanager
from time import perf_counter
from uuid import uuid4

import httpx
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, PlainTextResponse
from graphql import execute, validate
from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

from config import settings
from context import GraphQLRequestContext
from metrics import increment, observe_operation, render
from operations import OPERATIONS
from schema import schema
from security import inspect_query
from upstream import RequestMetadata, UpstreamClient

tracer = trace.get_tracer("funkey.graphql_bff")


def _compile_operation_budgets():
    """Validate immutable persisted documents once so request hot paths do no schema work."""
    budgets = {}
    for operation_id, operation in OPERATIONS.items():
        try:
            budget = inspect_query(operation.document)
        except ValueError as exc:
            raise RuntimeError(
                f"Persisted operation {operation.name} violates the security budget"
            ) from exc

        schema_errors = validate(schema, operation.document)
        if schema_errors:
            raise RuntimeError(
                f"Persisted operation {operation.name} is invalid: "
                f"{schema_errors[0].message}"
            )
        budgets[operation_id] = budget
    return budgets


_OPERATION_BUDGETS = _compile_operation_budgets()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Own the shared HTTP connection pool for all BFF upstream reads."""
    app.state.http = httpx.AsyncClient(
        limits=httpx.Limits(max_connections=64, max_keepalive_connections=32),
        follow_redirects=False,
    )
    try:
        yield
    finally:
        await app.state.http.aclose()


app = FastAPI(
    title="FunKey GraphQL Read BFF",
    version="1.0.0",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
    lifespan=lifespan,
)
FastAPIInstrumentor.instrument_app(app)


def _reject(status: int, code: str, message: str) -> JSONResponse:
    """Return a low-cardinality pre-execution GraphQL rejection."""
    increment("rejected")
    return JSONResponse(
        status_code=status,
        content={"errors": [{"message": message, "extensions": {"code": code}}]},
    )


@app.get("/live", include_in_schema=False)
def live() -> dict[str, str]:
    """Liveness never depends on downstream owner services."""
    return {"status": "live"}


@app.get("/ready", include_in_schema=False)
def ready() -> dict[str, object]:
    """Readiness confirms every allowlisted document compiled successfully."""
    return {
        "status": "ready",
        "persisted_operations": len(OPERATIONS),
        "compiled_operations": len(_OPERATION_BUDGETS),
    }


@app.get("/metrics", include_in_schema=False, response_class=PlainTextResponse)
def metrics() -> PlainTextResponse:
    """Expose counters and low-cardinality latency histograms."""
    return PlainTextResponse(render(), media_type="text/plain; version=0.0.4")


@app.post("/graphql")
async def graphql_endpoint(request: Request):
    """Execute one authenticated persisted read without request-time query validation."""
    request_started = perf_counter()

    raw = await request.body()
    if len(raw) > settings.max_request_bytes:
        return _reject(413, "PAYLOAD_TOO_LARGE", "GraphQL request payload is too large")

    try:
        payload = json.loads(raw or b"{}")
    except (json.JSONDecodeError, UnicodeDecodeError):
        return _reject(400, "BAD_REQUEST", "Request body must be valid JSON")
    if not isinstance(payload, dict):
        return _reject(400, "BAD_REQUEST", "Request body must be an object")
    if "query" in payload:
        return _reject(400, "PERSISTED_ONLY", "Ad-hoc GraphQL queries are disabled")

    operation_id = str(payload.get("id") or "").strip().lower()
    operation = OPERATIONS.get(operation_id)
    if operation is None:
        return _reject(400, "UNKNOWN_OPERATION", "Persisted operation is not allowlisted")

    variables = payload.get("variables") or {}
    if not isinstance(variables, dict):
        return _reject(400, "BAD_VARIABLES", "variables must be an object")

    authorization = request.headers.get("authorization", "").strip()
    if not authorization.lower().startswith("bearer "):
        return _reject(401, "UNAUTHENTICATED", "Bearer authentication is required")

    request_id = request.headers.get("x-request-id", "").strip() or str(uuid4())
    metadata = RequestMetadata(
        authorization=authorization,
        request_id=request_id,
        traceparent=request.headers.get("traceparent"),
    )
    upstream = UpstreamClient(request.app.state.http, metadata)
    context = GraphQLRequestContext.build(upstream, metadata)
    budget = _OPERATION_BUDGETS[operation_id]

    increment("requests")
    execution_started = perf_counter()
    try:
        with tracer.start_as_current_span(
            "graphql.persisted_operation",
            attributes={
                "graphql.operation.name": operation.name,
                "graphql.operation.id": operation.operation_id,
                "graphql.query.depth": budget.depth,
                "graphql.query.complexity": budget.complexity,
                "funkey.request_id": request_id,
            },
        ):
            result = execute(
                schema,
                operation.document,
                variable_values=variables,
                operation_name=operation.name,
                context_value=context,
            )
            if inspect.isawaitable(result):
                result = await result
    except Exception:
        observe_operation(
            operation.name,
            perf_counter() - request_started,
            outcome="error",
        )
        raise

    execution_seconds = perf_counter() - execution_started
    body: dict[str, object] = {"data": result.data}
    outcome = "ok"
    if result.errors:
        outcome = "error"
        increment("execution_errors")
        body["errors"] = [error.formatted for error in result.errors]

    total_seconds = perf_counter() - request_started
    observe_operation(operation.name, total_seconds, outcome=outcome)

    return JSONResponse(
        status_code=200,
        content=body,
        headers={
            "X-Request-ID": request_id,
            "Server-Timing": (
                f"graphql-exec;dur={execution_seconds * 1000:.2f}, "
                f"bff;dur={total_seconds * 1000:.2f}"
            ),
        },
    )
