from app.api.routes import (
    economy,
    inbox,
    inbox_calls,
    inbox_message_tools,
    inbox_preferences,
    inbox_stories,
    lucky_packets,
)

inbox.router.include_router(inbox_preferences.router)
inbox.router.include_router(inbox_stories.router)
inbox.router.include_router(inbox_message_tools.router)
inbox.router.include_router(inbox_calls.router)
economy.router.include_router(lucky_packets.router)
