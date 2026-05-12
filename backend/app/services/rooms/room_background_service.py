from app.schemas.rooms.room_background import RoomBackgroundConfigResponse


_CRICKET_BACKGROUNDS = [
    RoomBackgroundConfigResponse(
        id="cricket_floodlight_arena",
        name="Floodlight Arena",
        mode="cricket",
        source_type="cricket",
        unlock_type="free",
        ownership_type="free",
        asset_path="assets/images/room_backgrounds/cricket/default/floodlight_arena.webp",
        image_url=None,
        thumbnail_url=None,
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
        asset_path="assets/images/room_backgrounds/cricket/default/stadium_night.webp",
        image_url=None,
        thumbnail_url=None,
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
        asset_path="assets/images/room_backgrounds/cricket/default/royal_pitch.webp",
        image_url=None,
        thumbnail_url=None,
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
