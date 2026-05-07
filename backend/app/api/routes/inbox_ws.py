from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.database import get_db
from app.models.role import RoleName
from app.models.user import User
from app.services import role_service
from app.websocket.inbox_ws import inbox_ws_manager

router = APIRouter(tags=["Inbox WebSocket"])


async def _user_from_token(token: str, db: Session) -> User | None:
    payload = decode_access_token(token)
    if not payload:
        return None
    user_id = payload.get("sub")
    if not user_id:
        return None
    return db.query(User).filter(User.id == int(user_id)).first()


def _is_staff_for_inbox(user: User) -> bool:
    return role_service.get_primary_role(user) in {
        RoleName.FOUNDER_OWNER,
        RoleName.OWNER,
        RoleName.SUPERADMIN,
        RoleName.ADMIN,
        RoleName.MONITOR,
        RoleName.CS,
    }


@router.websocket("/ws/inbox")
async def inbox_websocket(websocket: WebSocket, db: Session = Depends(get_db)):
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=4401)
        return

    user = await _user_from_token(token, db)
    if not user or user.is_banned or not user.is_active:
        await websocket.close(code=4403)
        return

    await inbox_ws_manager.connect(user.id, websocket, is_staff=_is_staff_for_inbox(user))
    try:
        while True:
            payload = await websocket.receive_json()
            event = payload.get("event")
            if event == "ping":
                await websocket.send_json({"event": "pong"})
    except WebSocketDisconnect:
        inbox_ws_manager.disconnect(user.id, websocket)
    except Exception:
        inbox_ws_manager.disconnect(user.id, websocket)
        await websocket.close(code=1011)
