"""Compatibility aliases for Inbox service during beta schema/API convergence."""

from app.services import inbox_service

if not hasattr(inbox_service, "list_conversations_for_user") and hasattr(inbox_service, "list_conversations"):
    inbox_service.list_conversations_for_user = inbox_service.list_conversations
