from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class MvpFeatureCreate(BaseModel):
    item_type: str = Field(min_length=1, max_length=80)
    title: str = Field(min_length=1, max_length=160)
    description: str | None = None
    target_user_id: int | None = None
    room_public_id: str | None = None
    status: str = "active"
    amount: int = 0
    currency: str | None = None
    payload: dict[str, Any] = Field(default_factory=dict)


class MvpFeatureUpdate(BaseModel):
    item_type: str | None = None
    title: str | None = None
    description: str | None = None
    target_user_id: int | None = None
    room_public_id: str | None = None
    status: str | None = None
    amount: int | None = None
    currency: str | None = None
    payload: dict[str, Any] | None = None
    is_active: bool | None = None


class MvpFeatureResponse(BaseModel):
    id: int
    public_id: str
    feature: str
    item_type: str
    owner_user_id: int | None
    target_user_id: int | None
    room_public_id: str | None
    title: str
    description: str | None
    status: str
    amount: int
    currency: str | None
    payload: dict[str, Any]
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class MvpActionResponse(BaseModel):
    ok: bool = True
    message: str
    item: MvpFeatureResponse | None = None
