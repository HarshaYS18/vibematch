from enum import StrEnum


class RoomRealtimeEventType(StrEnum):
    ROOM_SNAPSHOT = "room.snapshot"
    ROOM_JOINED = "room.joined"
    ROOM_LEFT = "room.left"
    ROOM_PEER_LEFT = "room.peer_left"
    ROOM_SETTINGS_UPDATED = "room.settings.updated"
    ROOM_THEME_UPDATED = "room.theme.updated"
    ROOM_CHAT_MESSAGE_CREATED = "room.chat.message_created"

    SEAT_TAKEN = "seat.taken"
    SEAT_LEFT = "seat.left"
    SEAT_LOCKED = "seat.locked"
    SEAT_UNLOCKED = "seat.unlocked"
    SEAT_UPDATED = "seat.updated"

    MIC_SELF_MUTED = "mic.self_muted"
    MIC_SELF_UNMUTED = "mic.self_unmuted"
    MIC_ADMIN_MUTED = "mic.admin_muted"
    MIC_ADMIN_UNMUTED = "mic.admin_unmuted"

    ERROR = "error"


ROOM_EVENT_ALIASES: dict[str, RoomRealtimeEventType] = {
    # Current Flutter/live-room route names.
    "room/join": RoomRealtimeEventType.ROOM_JOINED,
    "room/leave": RoomRealtimeEventType.ROOM_LEFT,
    "seat/take": RoomRealtimeEventType.SEAT_TAKEN,
    "seat/leave": RoomRealtimeEventType.SEAT_LEFT,
    "admin/seat_assign": RoomRealtimeEventType.SEAT_TAKEN,
    "admin/seat_leave": RoomRealtimeEventType.SEAT_LEFT,
    "admin/seat_leave_lock": RoomRealtimeEventType.SEAT_LOCKED,
    "admin/seat_lock": RoomRealtimeEventType.SEAT_LOCKED,
    "admin/seat_unlock": RoomRealtimeEventType.SEAT_UNLOCKED,
    "mic/set_enabled": RoomRealtimeEventType.SEAT_UPDATED,
    "admin_mute/set": RoomRealtimeEventType.SEAT_UPDATED,
    "room_settings/seat_layout": RoomRealtimeEventType.ROOM_SETTINGS_UPDATED,
    "room_settings/background_theme": RoomRealtimeEventType.ROOM_THEME_UPDATED,
    "room_chat/send": RoomRealtimeEventType.ROOM_CHAT_MESSAGE_CREATED,
}


def canonical_room_event(raw_event_type: str) -> str:
    mapped = ROOM_EVENT_ALIASES.get(raw_event_type)
    if mapped:
        return mapped.value
    return raw_event_type.replace("/", ".")
