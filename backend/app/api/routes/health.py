from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.redis_client import get_redis
from app.database import get_db

router = APIRouter(prefix="/health", tags=["System"])


@router.get("")
def health_check():
    return {"status": "healthy", "service": "vibe-match-backend"}


@router.get("/live")
def liveness_check():
    return {"status": "ok"}


@router.get("/db")
def database_health_check(db: Session = Depends(get_db)):
    return {"status": "ok", "database": "connected", "result": db.execute(text("SELECT 1")).scalar()}


@router.get("/redis")
def redis_health_check():
    redis_client = get_redis()
    redis_client.set("vibematch_health", "ok", ex=30)
    return {"status": "ok", "redis": "connected", "value": redis_client.get("vibematch_health")}
