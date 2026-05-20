from app.models.call_session import CallSession
from app.models.inbox import InboxConversation


def push_payload_for_call(conversation: InboxConversation, call: CallSession, *, event: str, receiver_user_id: int) -> dict:
    """Payload contract for FCM/APNs/native incoming-call integrations.

    This function intentionally does not send push notifications. It gives every
    caller a single source of truth for notification data once platform keys and
    device-token storage are connected.
    """
    is_video = call.is_video_enabled or "VIDEO" in str(call.call_type)
    from_self = receiver_user_id == call.started_by_user_id
    return {
        "type": "inbox_call",
        "event": event,
        "conversation_id": conversation.public_id,
        "call_id": call.call_public_id,
        "call_type": "video" if is_video else "audio",
        "status": call.status.value if hasattr(call.status, "value") else str(call.status),
        "from_self": from_self,
        "started_by_user_id": call.started_by_user_id,
        "mediasoup_room_id": call.room_public_id,
        "title": "Video call" if is_video else "Voice call",
        "body": "Incoming video call" if is_video else "Incoming voice call",
        "actions": ["accept", "decline"] if not from_self and event == "inbox_call_started" else [],
    }


def media_join_contract(call: CallSession, *, user_id: int) -> dict:
    """Contract returned/broadcast for WebRTC/mediasoup gateway wiring.

    The mediasoup worker/router implementation can consume this shape later
    without changing Inbox call UI or call state APIs.
    """
    return {
        "provider": "mediasoup",
        "room_id": call.room_public_id,
        "call_id": call.call_public_id,
        "user_id": user_id,
        "requires_token": True,
        "signaling_namespace": "inbox_calls",
        "transports": {
            "send": None,
            "recv": None,
        },
        "tracks": {
            "audio": True,
            "video": bool(call.is_video_enabled),
        },
    }
