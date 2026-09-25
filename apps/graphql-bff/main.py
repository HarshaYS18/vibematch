"""FunKey Chunk 36 read-only GraphQL BFF."""

from __future__ import annotations

import inspect
import json
from contextlib import asynccontextmanager
from uuid import uuid4

import httpx
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, PlainTextResponse
from graphql import execute, validate
from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

from config import settings
from context import GraphQLRequestContext
from metrics import increment, render
from operations import OPERATIONS
from schema import schema
from security import inspect_query
from upstream import RequestMetadata, UpstreamClient

tracer = trace.get_tracer("funkey.graphql_bff")


@asynccontextmanager
async def lifespan(app: FastAPI):
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
    increment("rejected")
    return JSONResponse(
        status_code=status,
        content={"errors": [{"message": message, "extensions": {"code": code}}]},
    )


@app.get("/live", include_in_schema=False)
def live() -> dict[str, str]:
    return {"status": "live"}


@app.get("/ready", include_in_schema=False)
def ready() -> dict[str, object]:
    return {"status": "ready", "persisted_operations": len(OPERATIONS)}


@app.get("/metrics", include_in_schema=False, response_class=PlainTextResponse)
def metrics() -> PlainTextResponse:
    return PlainTextResponse(render(), media_type="text/plain; version=0.0.4")


@app.post("/graphql")
async def graphql_endpoint(request: Request):
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

    try:
        budget = inspect_query(operation.document)
        schema_errors = validate(schema, operation.document)
        if schema_errors:
            return _reject(500, "PERSISTED_QUERY_INVALID", schema_errors[0].message)
    except ValueError as exc:
        return _reject(500, "PERSISTED_QUERY_UNSAFE", str(exc))

    increment("requests")
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

    body: dict[str, object] = {"data": result.data}
    if result.errors:
        increment("execution_errors")
        body["errors"] = [error.formatted for error in result.errors]
    return JSONResponse(
        status_code=200,
        content=body,
        headers={"X-Request-ID": request_id},
    )
