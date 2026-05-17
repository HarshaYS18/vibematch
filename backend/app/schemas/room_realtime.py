from pydantic import BaseModel, Field


class RoomRealtimeBaseCommand(BaseModel):
    user_id: int | None = None


class RoomJoinCommand(RoomRealtimeBaseCommand):
    pass


class RoomLeaveCommand(RoomRealtimeBaseCommand):
    release_seat: bool = False


class RoomSeatTakeCommand(RoomRealtimeBaseCommand):
    seat_index: int = Field(ge=0)


class RoomSeatLeaveCommand(RoomRealtimeBaseCommand):
    pass


class RoomSeatLockCommand(RoomRealtimeBaseCommand):
    seat_index: int = Field(ge=0)
    locked: bool = True


class RoomMicCommand(RoomRealtimeBaseCommand):
    enabled: bool


class RoomAdminMuteCommand(RoomRealtimeBaseCommand):
    target_user_id: int
    muted: bool


class RoomSeatLayoutCommand(RoomRealtimeBaseCommand):
    seat_layout_id: str


class RoomBackgroundThemeCommand(RoomRealtimeBaseCommand):
    background_theme_id: str


class RoomChatSendCommand(RoomRealtimeBaseCommand):
    text: str
    message_type: str = "text"
