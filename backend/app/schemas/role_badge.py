from pydantic import BaseModel


class RoleBadgeResponse(BaseModel):
    role: str
    display_title: str
    badge_label: str
    pill_label: str
    group: str
    priority: int
    icon: str
    background_color: str
    text_color: str
    border_color: str
    show_verified_tick: bool = False
