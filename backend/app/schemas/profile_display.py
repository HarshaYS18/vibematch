from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class CanonicalUserDisplayResponse(BaseModel):
    backend_user_id: int
    public_user_id: int
    display_custom_id: int | None = None
    username: str | None = None
    display_name: str
    avatar_url: str | None = None
    cover_photo_url: str | None = None
    cover_photo_urls: list[str] = Field(default_factory=list)
    official_handle: str | None = None
    primary_role: str
    primary_role_badge: dict[str, Any] | None = None
    role_badges: list[dict[str, Any]] = Field(default_factory=list)
    official_role_badge: dict[str, Any] | None = None
    verified_official: bool = False
    room_role_label: str
    is_room_host: bool = False
    is_room_admin: bool = False
    is_room_member: bool = False
    admin_muted: bool = False
    vip: dict[str, Any] = Field(default_factory=dict)
    vip_level: int = 0
    svip_level: int = 0
    sent_level: int = 0
    received_level: int = 0
    monthly_sent_coins: int = 0
    monthly_received_coins: int = 0
    total_sent_coins: int = 0
    total_received_coins: int = 0
    name_gradient: dict[str, Any] = Field(default_factory=dict)
    equipped_items: dict[str, Any] = Field(default_factory=dict)
    profile_assets: dict[str, Any] = Field(default_factory=dict)
    stealth: dict[str, Any] = Field(default_factory=dict)


class StealthToggleRequest(BaseModel):
    enabled: bool
    reason: str = Field(..., min_length=3, max_length=255)


class StealthGrantRequest(BaseModel):
    target_user_id: int
    enabled: bool = True
    reason: str = Field(..., min_length=3, max_length=255)


class StealthStateResponse(BaseModel):
    user_id: int
    is_enabled: bool
    can_use_stealth: bool
    updated_at: datetime | None = None
