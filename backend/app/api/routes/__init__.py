from app.api.routes import inbox, inbox_preferences

inbox.router.include_router(inbox_preferences.router)
