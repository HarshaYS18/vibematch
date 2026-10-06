"""FunKey Search service.

Search is a disposable projection. OpenSearch failures may degrade search but
must never change durable business state.
"""

from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager

import httpx
import nats
from fastapi import FastAPI, Header, HTTPException, Query
from nats.js import api as js_api

from config import settings
from opensearch_store import OpenSearchStore
from projector import run_projector


@asynccontextmanager
async def lifespan(app: FastAPI):
    stop = asyncio.Event()
    http = httpx.AsyncClient(timeout=3.0)
    store = OpenSearchStore(
        http,
        base_url=settings.opensearch_url,
        index_prefix=settings.index_prefix,
    )
    await store.ensure_index()

    nc = await nats.connect(
        settings.nats_url,
        reconnect_time_wait=2,
        max_reconnect_attempts=-1,
    )
    js = nc.jetstream(timeout=3)
    subscription = await js.pull_subscribe(
        "funkey.events.>",
        durable=settings.durable,
        stream=settings.nats_stream,
        config=js_api.ConsumerConfig(
            durable_name=settings.durable,
            filter_subject="funkey.events.>",
            ack_policy=js_api.AckPolicy.EXPLICIT,
            ack_wait=120,
            max_ack_pending=500,
        ),
    )
    task = asyncio.create_task(run_projector(subscription, store, stop))
    app.state.store = store
    app.state.stop = stop
    try:
        yield
    finally:
        stop.set()
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)
        await nc.drain()
        await http.aclose()


app = FastAPI(
    title="FunKey Search",
    version="1.0.0",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
    lifespan=lifespan,
)


@app.get("/live")
async def live() -> dict[str, str]:
    return {"status": "live"}


@app.get("/ready")
async def ready() -> dict[str, str]:
    if not await app.state.store.ready():
        raise HTTPException(status_code=503, detail="search projection unavailable")
    return {"status": "ready"}


@app.get("/api/v1/search")
async def search(
    q: str = Query(min_length=1, max_length=120),
    kind: list[str] = Query(default=[]),
    limit: int = Query(default=30, ge=1, le=50),
    authorization: str = Header(default=""),
) -> dict[str, object]:
    if not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Bearer authentication is required")

    allowed = {"user", "room", "vibe"}
    kinds = [value for value in kind if value in allowed]
    if kind and len(kinds) != len(kind):
        raise HTTPException(status_code=400, detail="unsupported search kind")
    try:
        results = await app.state.store.search(q.strip(), kinds=kinds, limit=limit)
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=503,
            detail="search projection unavailable",
        ) from exc
    return {"results": results, "projection": "opensearch"}
