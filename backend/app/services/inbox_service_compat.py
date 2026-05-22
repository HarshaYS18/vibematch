"""Compatibility aliases for Inbox service during beta schema/API convergence.

Some routes were updated to call newer explicit service names while the
current service module still exposes the older shorter names. Keeping the
aliases here avoids replacing the large inbox_service.py file and keeps local
beta testing stable until the formal migration cleanup lands.
"""

from app.services import inbox_service


def install_inbox_service_aliases() -> None:
    if not hasattr(inbox_service, "list_conversations_for_user") and hasattr(inbox_service, "list_conversations"):
        inbox_service.list_conversations_for_user = inbox_service.list_conversations
