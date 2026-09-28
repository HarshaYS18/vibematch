from app.core.config import settings
from app.schemas.rooms.room_background import RoomBackgroundConfigResponse


def _media_cdn_url(object_key: str) -> str | None:
    base = settings.MEDIA_CDN_BASE_URL.strip().rstrip("/")
    if not base:
        return None
    return f"{base}/{object_key.lstrip('/')}"

_CRICKET_BACKGROUNDS = [
    RoomBackgroundConfigResponse(
        id="cricket_floodlight_arena",
        name="Floodlight Arena",
        mode="cricket",
        source_type="cricket",
        unlock_type="free",
        ownership_type="free",
        asset_path=None,
        image_url=_media_cdn_url("ui/rooms/cricket/backgrounds/v1/floodlight_arena.webp"),
        thumbnail_url=_media_cdn_url("ui/rooms/cricket/backgrounds/v1/floodlight_arena.webp"),
        accent="#65FF8F",
        overlay_opacity=0.48,
        fallback_colors=["#04130A", "#0B3E1F"],
        is_default=True,
        order=1,
    ),
    RoomBackgroundConfigResponse(
        id="cricket_stadium_night",
        name="Stadium Night",
        mode="cricket",
        source_type="cricket",
        unlock_type="free",
        ownership_type="free",
        asset_path=None,
        image_url=_media_cdn_url("ui/rooms/cricket/backgrounds/v1/stadium_night.webp"),
        thumbnail_url=_media_cdn_url("ui/rooms/cricket/backgrounds/v1/stadium_night.webp"),
        accent="#FFD36A",
        overlay_opacity=0.50,
        fallback_colors=["#07160D", "#254B1D"],
        order=2,
    ),
    RoomBackgroundConfigResponse(
        id="cricket_royal_pitch",
        name="Royal Pitch",
        mode="cricket",
        source_type="cricket",
        unlock_type="free",
        ownership_type="free",
        asset_path=None,
        image_url=_media_cdn_url("ui/rooms/cricket/backgrounds/v1/royal_pitch.webp"),
        thumbnail_url=_media_cdn_url("ui/rooms/cricket/backgrounds/v1/royal_pitch.webp"),
        accent="#12C7B7",
        overlay_opacity=0.46,
        fallback_colors=["#051B13", "#0C6040"],
        order=3,
    ),
]


def list_room_backgrounds(mode: str = "chat_room") -> list[RoomBackgroundConfigResponse]:
    normalized_mode = (mode or "chat_room").strip().lower()
    if normalized_mode in {"cricket", "cricket_mode"}:
        return [item for item in _CRICKET_BACKGROUNDS if item.is_active]
    return []
