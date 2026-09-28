"""FunKey Recommendation projection API."""

from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI, Header, HTTPException, Query
from redis.asyncio import Redis

from config import settings
from consumer import run_consumer
from store import RecommendationStore


@asynccontextmanager
async def lifespan(app: FastAPI):
    redis = Redis.from_url(settings.redis_url, decode_responses=False)
    store = RecommendationStore(redis, ttl_seconds=settings.feed_ttl_seconds)
    stop = asyncio.Event()
    task = asyncio.create_task(run_consumer(settings, store, stop))
    app.state.store = store
    try:
        yield
    finally:
        stop.set()
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)
        await redis.aclose()


app = FastAPI(
    title="FunKey Recommendation",
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
        raise HTTPException(status_code=503, detail="recommendation projection unavailable")
    return {"status": "ready"}


@app.get("/api/v1/recommendations")
async def recommendations(
    public_user_id: str = Query(min_length=1, max_length=128),
    limit: int = Query(default=30, ge=1, le=100),
    authorization: str = Header(default=""),
) -> dict[str, object]:
    if not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Bearer authentication is required")
    return {
        "items": await app.state.store.feed(public_user_id, limit=limit),
        "projection": "recommendation-v1",
    }
