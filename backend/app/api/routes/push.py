from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.push import PushDeviceTokenResponse, PushDeviceTokenUpsertRequest
from app.services import push_notification_service

router = APIRouter(prefix="/push", tags=["Push Notifications"])


@router.post("/device-token", response_model=PushDeviceTokenResponse)
def upsert_device_token(
    request: PushDeviceTokenUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    token = push_notification_service.upsert_device_token(
        db,
        user=current_user,
        device_id=request.device_id,
        platform=request.platform,
        fcm_token=request.fcm_token,
        app_package=request.app_package,
    )
    return PushDeviceTokenResponse(
        device_id=token.device_id,
        platform=token.platform,
        is_active=token.is_active,
    )


@router.delete("/device-token/{device_id}", response_model=dict)
def delete_device_token(
    device_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    push_notification_service.deactivate_device_token(db, user=current_user, device_id=device_id)
    return {"ok": True}
