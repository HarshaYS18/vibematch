from pydantic import BaseModel, Field


class LoveBondInventoryItemResponse(BaseModel):
    card_type: str
    card_name: str
    quantity: int
    reserved_quantity: int
    available_quantity: int
    source: str | None = None


class LoveBondInventoryResponse(BaseModel):
    items: list[LoveBondInventoryItemResponse]


class LoveBondSendRequest(BaseModel):
    receiver_public_user_id: int = Field(..., gt=0)
    card_type: str = Field(..., min_length=2, max_length=40)


class LoveBondRequestResponse(BaseModel):
    id: str
    sender_public_user_id: int
    sender_name: str
    receiver_public_user_id: int
    receiver_name: str
    card_type: str
    card_name: str
    status: str
    created_at: str | None = None
    responded_at: str | None = None


class LoveBondRequestListResponse(BaseModel):
    requests: list[LoveBondRequestResponse]


class LoveBondResponse(BaseModel):
    id: str
    card_type: str
    status: str
    love_score: int
    level: int
    partner_public_user_id: int
    partner_name: str
    partner_avatar_url: str | None = None
    partner_gender: str | None = None
    started_at: str | None = None


class LoveBondListResponse(BaseModel):
    bonds: list[LoveBondResponse]
