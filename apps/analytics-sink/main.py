"""FunKey analytics projection sink."""

from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.responses import PlainTextResponse

from config import settings
from consumer import run_consumer
from sink import AnalyticsSink


@asynccontextmanager
async def lifespan(app: FastAPI):
    http = httpx.AsyncClient()
    sink = AnalyticsSink(settings, http)
    await sink.ensure_clickhouse()
    stop = asyncio.Event()
    counters = {"written": 0, "invalid": 0, "sink_failures": 0}
    task = asyncio.create_task(run_consumer(settings, sink, stop, counters))
    app.state.sink = sink
    app.state.counters = counters
    try:
        yield
    finally:
        stop.set()
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)
        await http.aclose()


app = FastAPI(
    title="FunKey Analytics Sink",
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
    if not await app.state.sink.ready():
        raise HTTPException(status_code=503, detail="analytics sink unavailable")
    return {"status": "ready"}


@app.get("/metrics", response_class=PlainTextResponse)
async def metrics() -> PlainTextResponse:
    c = app.state.counters
    body = (
        f"funkey_analytics_events_written_total {c['written']}\n"
        f"funkey_analytics_events_invalid_total {c['invalid']}\n"
        f"funkey_analytics_sink_failures_total {c['sink_failures']}\n"
    )
    return PlainTextResponse(body, media_type="text/plain; version=0.0.4")
