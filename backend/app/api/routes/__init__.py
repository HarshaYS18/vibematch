from app.api.routes import inbox, inbox_message_tools, inbox_preferences, inbox_stories

inbox.router.include_router(inbox_preferences.router)
inbox.router.include_router(inbox_stories.router)
inbox.router.include_router(inbox_message_tools.router)
