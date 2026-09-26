from sqlalchemy.orm import Session

from app.models.inbox import InboxConversation
from app.models.inbox_preferences import (
    InboxConversationUserSetting,
    InboxMessageUserState,
    InboxUserPreference,
)
from app.models.user import User

VISIBILITY_VALUES = {"everyone", "friends", "nobody"}
CHAT_THEMES = {"pearl", "midnight", "royal", "ocean", "rose"}
WALLPAPERS = {"premium_pearl", "midnight_blur", "royal_plum", "ocean_glass", "rose_gold"}


def get_preferences_read_only(db: Session, user: User) -> InboxUserPreference:
    """Return persisted preferences or an unsaved default projection."""

    preference = (
        db.query(InboxUserPreference)
        .filter(InboxUserPreference.user_id == user.id)
        .first()
    )
    return preference or InboxUserPreference(
        user_id=user.id,
        strangers_can_message=True,
        strangers_can_mention_in_vibes=True,
        read_receipts_enabled=True,
        online_visibility="everyone",
        last_seen_visibility="everyone",
        typing_activity_visibility="everyone",
        story_visibility="friends",
        device_unlock_enabled=False,
        default_chat_theme="pearl",
        default_wallpaper_key="premium_pearl",
        default_wallpaper_url=None,
    )


def get_or_create_preferences(db: Session, user: User) -> InboxUserPreference:
    preference = db.query(InboxUserPreference).filter(InboxUserPreference.user_id == user.id).first()
    if preference is not None:
        return preference
    preference = InboxUserPreference(user_id=user.id)
    db.add(preference)
    db.commit()
    db.refresh(preference)
    return preference


def serialize_preferences(preference: InboxUserPreference) -> dict:
    return {
        "strangers_can_message": preference.strangers_can_message,
        "strangers_can_mention_in_vibes": preference.strangers_can_mention_in_vibes,
        "read_receipts_enabled": preference.read_receipts_enabled,
        "online_visibility": preference.online_visibility,
        "last_seen_visibility": preference.last_seen_visibility,
        "typing_activity_visibility": preference.typing_activity_visibility,
        "story_visibility": preference.story_visibility,
        "device_unlock_enabled": preference.device_unlock_enabled,
        "default_chat_theme": preference.default_chat_theme,
        "default_wallpaper_key": preference.default_wallpaper_key,
        "default_wallpaper_url": preference.default_wallpaper_url,
    }


def update_preferences(
    db: Session,
    user: User,
    strangers_can_message: bool | None = None,
    strangers_can_mention_in_vibes: bool | None = None,
    read_receipts_enabled: bool | None = None,
    online_visibility: str | None = None,
    last_seen_visibility: str | None = None,
    typing_activity_visibility: str | None = None,
    story_visibility: str | None = None,
    device_unlock_enabled: bool | None = None,
    default_chat_theme: str | None = None,
    default_wallpaper_key: str | None = None,
    default_wallpaper_url: str | None = None,
) -> InboxUserPreference:
    preference = get_or_create_preferences(db, user)

    if strangers_can_message is not None:
        preference.strangers_can_message = strangers_can_message
    if strangers_can_mention_in_vibes is not None:
        preference.strangers_can_mention_in_vibes = strangers_can_mention_in_vibes
    if read_receipts_enabled is not None:
        preference.read_receipts_enabled = read_receipts_enabled
    if device_unlock_enabled is not None:
        preference.device_unlock_enabled = device_unlock_enabled

    for field_name, value in {
        "online_visibility": online_visibility,
        "last_seen_visibility": last_seen_visibility,
        "typing_activity_visibility": typing_activity_visibility,
        "story_visibility": story_visibility,
    }.items():
        if value is None:
            continue
        if value not in VISIBILITY_VALUES:
            raise ValueError(f"Invalid {field_name}: {value}")
        setattr(preference, field_name, value)

    if default_chat_theme is not None:
        if default_chat_theme not in CHAT_THEMES:
            raise ValueError("Invalid chat theme")
        preference.default_chat_theme = default_chat_theme
    if default_wallpaper_key is not None:
        if default_wallpaper_key not in WALLPAPERS:
            raise ValueError("Invalid wallpaper")
        preference.default_wallpaper_key = default_wallpaper_key
    if default_wallpaper_url is not None:
        preference.default_wallpaper_url = default_wallpaper_url.strip() or None

    db.add(preference)
    db.commit()
    db.refresh(preference)
    return preference


def get_or_create_conversation_setting(
    db: Session,
    conversation: InboxConversation,
    user: User,
) -> InboxConversationUserSetting:
    setting = (
        db.query(InboxConversationUserSetting)
        .filter(
            InboxConversationUserSetting.conversation_id == conversation.id,
            InboxConversationUserSetting.user_id == user.id,
        )
        .first()
    )
    if setting is not None:
        return setting
    setting = InboxConversationUserSetting(conversation_id=conversation.id, user_id=user.id)
    db.add(setting)
    db.commit()
    db.refresh(setting)
    return setting


def update_conversation_theme(
    db: Session,
    conversation: InboxConversation,
    user: User,
    chat_theme: str | None = None,
    wallpaper_key: str | None = None,
    wallpaper_url: str | None = None,
) -> InboxConversationUserSetting:
    setting = get_or_create_conversation_setting(db, conversation, user)
    if chat_theme is not None:
        if chat_theme not in CHAT_THEMES:
            raise ValueError("Invalid chat theme")
        setting.chat_theme = chat_theme
    if wallpaper_key is not None:
        if wallpaper_key not in WALLPAPERS:
            raise ValueError("Invalid wallpaper")
        setting.wallpaper_key = wallpaper_key
    if wallpaper_url is not None:
        setting.wallpaper_url = wallpaper_url.strip() or None
    db.add(setting)
    db.commit()
    db.refresh(setting)
    return setting


def conversation_theme_payload(db: Session, conversation: InboxConversation, user: User) -> dict:
    preference = get_preferences_read_only(db, user)
    setting = (
        db.query(InboxConversationUserSetting)
        .filter(
            InboxConversationUserSetting.conversation_id == conversation.id,
            InboxConversationUserSetting.user_id == user.id,
        )
        .first()
    )
    return {
        "chat_theme": setting.chat_theme if setting and setting.chat_theme else preference.default_chat_theme,
        "wallpaper_key": setting.wallpaper_key if setting and setting.wallpaper_key else preference.default_wallpaper_key,
        "wallpaper_url": setting.wallpaper_url if setting and setting.wallpaper_url else preference.default_wallpaper_url,
    }


def mark_message_deleted_for_user(db: Session, conversation: InboxConversation, user: User, message_public_id: str) -> bool:
    message = next((item for item in conversation.messages if item.public_id == message_public_id), None)
    if message is None:
        return False
    state = (
        db.query(InboxMessageUserState)
        .filter(InboxMessageUserState.message_id == message.id, InboxMessageUserState.user_id == user.id)
        .first()
    )
    if state is None:
        state = InboxMessageUserState(
            message_id=message.id,
            conversation_id=conversation.id,
            user_id=user.id,
            is_deleted_for_user=True,
        )
    else:
        state.is_deleted_for_user = True
    db.add(state)
    db.commit()
    return True


def visible_messages_for_user(db: Session, conversation: InboxConversation, user: User):
    deleted_ids = {
        item.message_id
        for item in db.query(InboxMessageUserState)
        .filter(
            InboxMessageUserState.conversation_id == conversation.id,
            InboxMessageUserState.user_id == user.id,
            InboxMessageUserState.is_deleted_for_user.is_(True),
        )
        .all()
    }
    return [message for message in conversation.messages if message.id not in deleted_ids]
