from typing import Any, Literal

from pydantic import BaseModel, Field


class WebSocketEnvelope(BaseModel):
    type: str = Field(..., examples=["room.message.send"])
    room_id: str | None = Field(default=None, examples=["VM123456"])
    user_id: str | None = Field(default=None, examples=["6418000001"])
    request_id: str | None = Field(
        default=None,
        description="Client generated ID so Flutter can reconcile optimistic UI events.",
    )
    payload: dict[str, Any] = Field(default_factory=dict)


class WebSocketAck(BaseModel):
    type: Literal["system.ack"] = "system.ack"
    request_id: str | None = None
    ok: bool = True
    message: str = "ok"


class WebSocketError(BaseModel):
    type: Literal["system.error"] = "system.error"
    request_id: str | None = None
    ok: bool = False
    code: str
    message: str


class RoomPresencePayload(BaseModel):
    room_id: str
    online_count: int
    connection_count: int


class RoomPresenceEvent(BaseModel):
    type: Literal["room.presence.updated"] = "room.presence.updated"
    payload: RoomPresencePayload


class RoomMessagePayload(BaseModel):
    room_id: str
    sender_user_id: str
    sender_name: str = "Guest"
    text: str
    created_at: str


class RoomMessageEvent(BaseModel):
    type: Literal["room.message.created"] = "room.message.created"
    payload: RoomMessagePayload
