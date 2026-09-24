from fastapi import APIRouter, Depends, FastAPI, Header, HTTPException
from fastapi.responses import PlainTextResponse
from sqlalchemy import text
from app.api.routes import admin, auth, moderation, users
from app.core.config import settings
from app.core.security import decode_access_token
from app.core.operational import install_query_counter, operational_middleware, render_metrics
from app.core.telemetry import configure_telemetry
from app.database import get_db
from app.models.user import User
from app.services import identity_session_service
from database import engine, get_identity_db
from internal import router as internal_router

settings.validate_identity_service()
app=FastAPI(title="FunKey Identity Service",version="1.0.0",docs_url=None,redoc_url=None)
app.middleware("http")(operational_middleware)
app.dependency_overrides[get_db]=get_identity_db

def get_identity_current_user(
    authorization: str | None = Header(default=None),
    db=Depends(get_identity_db),
) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")
    token = authorization.replace("Bearer ", "", 1).strip()
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    subject = str(payload.get("sub") or "").strip()
    if not subject.isdigit():
        raise HTTPException(status_code=401, detail="Invalid token subject")
    user = db.query(User).filter(User.id == int(subject)).first()
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    if user.is_banned:
        raise HTTPException(status_code=403, detail="User is banned")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="User is inactive")
    token_device = str(payload.get("device_id") or "").strip()
    active_device = (user.last_device_id or "").strip()
    if active_device and token_device != active_device:
        raise HTTPException(status_code=401, detail="Session replaced by a newer login")
    sid = str(payload.get("sid") or "").strip()
    if sid and not identity_session_service.is_session_active(
        db,
        user_id=user.id,
        session_id=sid,
        device_id=token_device or None,
    ):
        raise HTTPException(status_code=401, detail="Session is no longer active")
    return user

app.dependency_overrides[users.get_current_user] = get_identity_current_user

api=APIRouter(prefix="/api/v1")
api.include_router(auth.router)
api.include_router(admin.router)
api.include_router(moderation.router)
app.include_router(api)
app.include_router(internal_router)

@app.get("/live",include_in_schema=False)
def live(): return {"status":"live"}
@app.get("/ready",include_in_schema=False)
def ready():
    with engine.connect() as c: c.execute(text("SELECT 1"))
    return {"status":"ready"}
@app.get("/metrics",include_in_schema=False,response_class=PlainTextResponse)
def metrics(): return PlainTextResponse(render_metrics(engine.pool),media_type="text/plain; version=0.0.4")
install_query_counter(engine)
configure_telemetry("funkey-identity",app=app,engine=engine)
