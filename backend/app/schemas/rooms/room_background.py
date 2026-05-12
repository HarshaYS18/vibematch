from pydantic import BaseModel, Field


class RoomBackgroundConfigResponse(BaseModel):
    id: str
    name: str
    mode: str = Field(default="chat_room")
    source_type: str = Field(default="chatRoom")
    unlock_type: str = Field(default="free")
    ownership_type: str = Field(default="free")
    asset_path: str | None = None
    image_url: str | None = None
    thumbnail_url: str | None = None
    accent: str = Field(default="#12C7B7")
    overlay_opacity: float = Field(default=0.42)
    fallback_colors: list[str] = Field(default_factory=list)
    is_default: bool = False
    is_active: bool = True
    order: int = 0
