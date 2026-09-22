from pydantic import BaseModel, Field


class RoomRealtimeBaseCommand(BaseModel):
    user_id: int | None = None


class RoomJoinCommand(RoomRealtimeBaseCommand):
    lock_password: str | None = Field(default=None, max_length=128)


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


class RoomWatchPartyCommand(RoomRealtimeBaseCommand):
    action: str = Field(min_length=1, max_length=32)
    expected_revision: int | None = Field(default=None, ge=0)
    provider: str | None = Field(default=None, max_length=64)
    content_id: str | None = Field(default=None, max_length=500)
    content_url: str | None = Field(default=None, max_length=2000)
    content_title: str | None = Field(default=None, max_length=500)
    position_ms: int | None = Field(default=None, ge=0)
    playback_state: str | None = Field(default=None, max_length=20)
    playback_rate: float | None = Field(default=None, ge=0.25, le=4.0)
    target_user_id: int | None = Field(default=None, gt=0)
