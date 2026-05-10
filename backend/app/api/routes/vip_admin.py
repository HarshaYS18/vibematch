from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.vip_status import UserVipStatusResponse, UserVipStatusUpdateRequest
from app.services import vip_status_service

router = APIRouter(prefix="/admin/vip", tags=["VIP Admin"])


@router.get("/users/{public_user_id}", response_model=UserVipStatusResponse)
def get_user_vip_status(public_user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return UserVipStatusResponse(**vip_status_service.get_status_by_public_id(db, public_user_id))


@router.put("/users/{public_user_id}", response_model=UserVipStatusResponse)
def update_user_vip_status(public_user_id: int, payload: UserVipStatusUpdateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return UserVipStatusResponse(**vip_status_service.update_status_by_public_id(db, current_user, public_user_id, payload.model_dump()))
