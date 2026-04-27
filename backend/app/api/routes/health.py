from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.redis_client import get_redis

router = APIRouter()


@router.get("/")
def health_check():
    return {
        "status": "ok",
        "message": "VibeMatch backend is healthy",
    }


@router.get("/db")
def database_health_check(db: Session = Depends(get_db)):
    result = db.execute(text("SELECT 1")).scalar()

    return {
        "status": "ok",
        "database": "connected",
        "result": result,
    }


@router.get("/redis")
def redis_health_check():
    redis_client = get_redis()
    redis_client.set("vibematch_health", "ok", ex=30)
    value = redis_client.get("vibematch_health")

    return {
        "status": "ok",
        "redis": "connected",
        "value": value,
    }