from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.services import gift_catalog_service, lucky_gift_props_service
from sqlalchemy.orm import Session

router = APIRouter(prefix="/gifts", tags=["Gifts"])


class LuckyGiftRollRequest(BaseModel):
    gift_id: str = Field(..., min_length=1, max_length=80)
    quantity: int = Field(default=1, gt=0, le=999)
    house_risk_score: int = Field(default=0, ge=0, le=100)


@router.get("/catalog")
def get_gift_catalog(current_user: User = Depends(get_current_user)):
    return gift_catalog_service.list_gifts()


@router.get("/catalog/{gift_id}")
def get_gift_detail(gift_id: str, current_user: User = Depends(get_current_user)):
    gift = gift_catalog_service.find_gift(gift_id)
    if gift is None:
        raise HTTPException(status_code=404, detail="Gift not found")
    return gift


@router.post("/lucky/roll")
def roll_lucky_gift(payload: LuckyGiftRollRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    gift = gift_catalog_service.find_gift(payload.gift_id)
    if gift is None:
        raise HTTPException(status_code=404, detail="Gift not found")
    if gift.get("gift_type") != "lucky":
        raise HTTPException(status_code=400, detail="Gift is not a lucky gift")
    try:
        return lucky_gift_props_service.roll_lucky_gift(
            db,
            gift_id=payload.gift_id,
            gift_name=str(gift.get("name") or payload.gift_id.replace("_", " ").title()),
            base_coin_value=int(gift["coin_value"]),
            quantity=payload.quantity,
            house_risk_score=payload.house_risk_score,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
