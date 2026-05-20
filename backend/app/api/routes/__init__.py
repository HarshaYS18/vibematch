from app.api.routes import inbox, inbox_preferences, inbox_stories

inbox.router.include_router(inbox_preferences.router)
inbox.router.include_router(inbox_stories.router)
