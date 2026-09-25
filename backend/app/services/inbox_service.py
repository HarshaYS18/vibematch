import base64
import json
from datetime import datetime, timedelta
from uuid import uuid4

from sqlalchemy import and_, case, exists, func, or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload, selectinload

from app.models.inbox import InboxConversation, InboxConversationType, InboxMessage, InboxMessageStatus, InboxMessageType, InboxParticipant, InboxReadReceipt, InboxReport, InboxReportStatus
from app.models.inbox_preferences import InboxMessageUserState
from app.models.user import User
from app.websocket.inbox_ws import inbox_ws_manager

DEFAULT_COLORS = ["#6D5DF6", "#E84C72"]
TEAM_PUBLIC_ID_PREFIX = "team_official"
OFFICIAL_TEAM_NAME = "FunKey Team"
OFFICIAL_TEAM_AVATAR_TEXT = "FK"
OFFICIAL_TEAM_LOGO_ASSET = "assets/branding/funkey_logo.png"
ACTIVE_MESSAGE_WINDOW = 50
MAX_MESSAGE_PAGE_SIZE = 100
MAX_CONVERSATION_PAGE_SIZE = 100
READ_RECEIPT_WINDOW = 100


def _public_id(prefix: str) -> str:
    return f"{prefix}_{uuid4().hex[:20]}"


def _team_public_id(user: User) -> str:
    return f"{TEAM_PUBLIC_ID_PREFIX}_{user.id}"


def _time_label(value: datetime | None) -> str:
    if value is None:
        return "Now"
    diff = datetime.utcnow() - value
    if diff.total_seconds() < 60:
        return "Now"
    if diff.total_seconds() < 3600:
        return f"{int(diff.total_seconds() // 60)}m"
    if diff.total_seconds() < 86400:
        return f"{int(diff.total_seconds() // 3600)}h"
    return f"{diff.days}d"


def _display_name(user: User | None) -> str:
    if user is None:
        return OFFICIAL_TEAM_NAME
    return user.display_name or user.username or f"User {user.public_user_id}"


def _avatar_text(title: str) -> str:
    parts = [part for part in title.strip().split(" ") if part]
    if not parts:
        return OFFICIAL_TEAM_AVATAR_TEXT
    if len(parts) == 1:
        return parts[0][:2].upper()
    return f"{parts[0][0]}{parts[1][0]}".upper()


def _official_team_metadata(existing: dict | None = None) -> dict:
    metadata = dict(existing or {})
    metadata["colors"] = ["#008069", "#25D366"]
    metadata["avatar_url"] = OFFICIAL_TEAM_LOGO_ASSET
    metadata["avatar_asset"] = OFFICIAL_TEAM_LOGO_ASSET
    metadata["brand_name"] = "FunKey"
    return metadata


def _other_participant_user(conversation: InboxConversation, current_user: User) -> User | None:
    for participant in conversation.participants:
        if participant.user_id != current_user.id:
            return participant.user
    return None


def participant_user_ids(conversation: InboxConversation) -> list[int]:
    return [participant.user_id for participant in conversation.participants]


def ensure_team_conversation(db: Session, user: User) -> InboxConversation:
    user_team_public_id = _team_public_id(user)
    conversation = (
        db.query(InboxConversation)
        .join(InboxParticipant)
        .filter(
            InboxConversation.conversation_type == InboxConversationType.OFFICIAL.value,
            InboxConversation.is_official.is_(True),
            InboxParticipant.user_id == user.id,
        )
        .first()
    )
    if conversation:
        needs_update = (
            conversation.title != OFFICIAL_TEAM_NAME
            or conversation.avatar_text != OFFICIAL_TEAM_AVATAR_TEXT
            or (conversation.metadata_json or {}).get("avatar_url") != OFFICIAL_TEAM_LOGO_ASSET
        )
        if needs_update:
            conversation.title = OFFICIAL_TEAM_NAME
            conversation.avatar_text = OFFICIAL_TEAM_AVATAR_TEXT
            conversation.metadata_json = _official_team_metadata(conversation.metadata_json)
            db.add(conversation)
            db.commit()
            db.refresh(conversation)
        return conversation

    conversation = db.query(InboxConversation).filter(InboxConversation.public_id == user_team_public_id).first()
    if conversation:
        conversation.title = OFFICIAL_TEAM_NAME
        conversation.avatar_text = OFFICIAL_TEAM_AVATAR_TEXT
        conversation.metadata_json = _official_team_metadata(conversation.metadata_json)
        participant = db.query(InboxParticipant).filter(InboxParticipant.conversation_id == conversation.id, InboxParticipant.user_id == user.id).first()
        if participant is None:
            db.add(InboxParticipant(conversation_id=conversation.id, user_id=user.id))
        db.add(conversation)
        db.commit()
        db.refresh(conversation)
        return conversation

    conversation = InboxConversation(
        public_id=user_team_public_id,
        title=OFFICIAL_TEAM_NAME,
        avatar_text=OFFICIAL_TEAM_AVATAR_TEXT,
        conversation_type=InboxConversationType.OFFICIAL.value,
        is_official=True,
        metadata_json=_official_team_metadata(),
    )
    db.add(conversation)

    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        existing = db.query(InboxConversation).filter(InboxConversation.public_id == user_team_public_id).first()
        if existing:
            existing.title = OFFICIAL_TEAM_NAME
            existing.avatar_text = OFFICIAL_TEAM_AVATAR_TEXT
            existing.metadata_json = _official_team_metadata(existing.metadata_json)
            participant = db.query(InboxParticipant).filter(InboxParticipant.conversation_id == existing.id, InboxParticipant.user_id == user.id).first()
            if participant is None:
                db.add(InboxParticipant(conversation_id=existing.id, user_id=user.id))
            db.add(existing)
            db.commit()
            db.refresh(existing)
            return existing
        raise

    db.add(InboxParticipant(conversation_id=conversation.id, user_id=user.id))
    db.add(
        InboxMessage(
            public_id=_public_id("msg"),
            conversation_id=conversation.id,
            sender_user_id=None,
            sender_name=OFFICIAL_TEAM_NAME,
            message_type=InboxMessageType.SYSTEM.value,
            text="Welcome to FunKey Team. Official safety, account, report, and system updates appear here.",
            status=InboxMessageStatus.READ.value,
        )
    )
    db.commit()
    db.refresh(conversation)
    return conversation


def _direct_pair_key(conversation: InboxConversation) -> tuple[int, int] | None:
    if conversation.is_official:
        return None
    participant_ids = sorted(participant_user_ids(conversation))
    if len(participant_ids) != 2:
        return None
    return (participant_ids[0], participant_ids[1])


def _merge_duplicate_direct_conversations_for_user(db: Session, user: User) -> None:
    conversations = (
        db.query(InboxConversation)
        .join(InboxParticipant)
        .filter(
            InboxParticipant.user_id == user.id,
            InboxParticipant.is_deleted_for_user.is_(False),
            InboxConversation.is_official.is_(False),
        )
        .order_by(InboxConversation.created_at.asc(), InboxConversation.updated_at.asc())
        .all()
    )

    grouped: dict[tuple[int, int], list[InboxConversation]] = {}
    for conversation in conversations:
        pair_key = _direct_pair_key(conversation)
        if pair_key is None:
            continue
        grouped.setdefault(pair_key, []).append(conversation)

    changed = False

    for pair_conversations in grouped.values():
        if len(pair_conversations) <= 1:
            continue

        pair_conversations.sort(key=lambda item: (item.created_at, item.id))
        main = pair_conversations[0]
        duplicates = pair_conversations[1:]

        if main.conversation_type != InboxConversationType.CHAT.value:
            main.conversation_type = InboxConversationType.CHAT.value
            changed = True

        for duplicate in duplicates:
            for message in list(duplicate.messages):
                message.conversation_id = main.id
                changed = True

            if not main.current_room_name and duplicate.current_room_name:
                main.current_room_name = duplicate.current_room_name
            if not main.room_public_id and duplicate.room_public_id:
                main.room_public_id = duplicate.room_public_id

            main.is_muted = main.is_muted or duplicate.is_muted
            main.is_pinned = main.is_pinned or duplicate.is_pinned
            main.is_archived = main.is_archived and duplicate.is_archived
            main.updated_at = max(main.updated_at, duplicate.updated_at)

            main_metadata = dict(main.metadata_json or {})
            duplicate_metadata = dict(duplicate.metadata_json or {})
            for key, value in duplicate_metadata.items():
                main_metadata.setdefault(key, value)
            main.metadata_json = main_metadata

            db.delete(duplicate)
            changed = True

    if changed:
        db.commit()




def _encode_cursor(payload: dict) -> str:
    raw = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def _decode_cursor(cursor: str | None) -> dict | None:
    value = (cursor or "").strip()
    if not value:
        return None
    try:
        padded = value + "=" * ((4 - len(value) % 4) % 4)
        decoded = json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))
    except Exception as exc:
        raise ValueError("Invalid Inbox cursor") from exc
    if not isinstance(decoded, dict):
        raise ValueError("Invalid Inbox cursor")
    return decoded


def list_conversations_page(
    db: Session,
    user: User,
    *,
    limit: int = 40,
    cursor: str | None = None,
) -> tuple[list[tuple[InboxConversation, InboxParticipant]], str | None]:
    """Read-only keyset page. No repair/bootstrap mutation is allowed here."""

    page_size = max(1, min(int(limit or 40), MAX_CONVERSATION_PAGE_SIZE))
    pin_rank = case((InboxParticipant.is_pinned.is_(True), 1), else_=0)
    query = (
        db.query(InboxConversation, InboxParticipant)
        .options(
            selectinload(InboxConversation.participants)
            .joinedload(InboxParticipant.user)
        )
        .join(
            InboxParticipant,
            InboxParticipant.conversation_id == InboxConversation.id,
        )
        .filter(
            InboxParticipant.user_id == user.id,
            InboxParticipant.is_deleted_for_user.is_(False),
        )
    )

    decoded = _decode_cursor(cursor)
    if decoded is not None:
        try:
            cursor_pinned = 1 if bool(decoded["pinned"]) else 0
            cursor_updated_at = datetime.fromisoformat(str(decoded["updated_at"]))
            cursor_id = int(decoded["id"])
        except (KeyError, TypeError, ValueError) as exc:
            raise ValueError("Invalid Inbox cursor") from exc
        query = query.filter(
            or_(
                pin_rank < cursor_pinned,
                and_(
                    pin_rank == cursor_pinned,
                    or_(
                        InboxConversation.updated_at < cursor_updated_at,
                        and_(
                            InboxConversation.updated_at == cursor_updated_at,
                            InboxConversation.id < cursor_id,
                        ),
                    ),
                ),
            )
        )

    rows = (
        query.order_by(
            pin_rank.desc(),
            InboxConversation.updated_at.desc(),
            InboxConversation.id.desc(),
        )
        .limit(page_size + 1)
        .all()
    )
    has_more = len(rows) > page_size
    rows = rows[:page_size]
    next_cursor = None
    if has_more and rows:
        conversation, participant = rows[-1]
        next_cursor = _encode_cursor(
            {
                "pinned": bool(participant.is_pinned),
                "updated_at": conversation.updated_at.isoformat(),
                "id": int(conversation.id),
            }
        )
    return rows, next_cursor


def list_conversations(db: Session, user: User) -> list[InboxConversation]:
    rows, _ = list_conversations_page(
        db,
        user,
        limit=MAX_CONVERSATION_PAGE_SIZE,
    )
    return [conversation for conversation, _participant in rows]

def get_conversation_for_user(db: Session, user: User, conversation_public_id: str) -> InboxConversation | None:
    return db.query(InboxConversation).join(InboxParticipant).filter(InboxConversation.public_id == conversation_public_id, InboxParticipant.user_id == user.id).first()


def _same_direct_pair(conversation: InboxConversation, user_a_id: int, user_b_id: int) -> bool:
    if conversation.is_official:
        return False
    participant_ids = set(participant_user_ids(conversation))
    return participant_ids == {user_a_id, user_b_id}


def _dedupe_conversations_for_user(conversations: list[InboxConversation]) -> list[InboxConversation]:
    visible: list[InboxConversation] = []
    seen_pairs: set[tuple[int, int]] = set()

    for conversation in conversations:
        if not conversation.is_official:
            participant_ids = sorted(participant_user_ids(conversation))
            if len(participant_ids) == 2:
                pair_key = (participant_ids[0], participant_ids[1])
                if pair_key in seen_pairs:
                    continue
                seen_pairs.add(pair_key)

        visible.append(conversation)

    return visible




def conversation_message_windows(
    db: Session,
    conversations: list[InboxConversation],
    user: User,
    *,
    limit: int = ACTIVE_MESSAGE_WINDOW,
) -> tuple[
    dict[int, list[InboxMessage]],
    dict[int, str | None],
    dict[int, bool],
    dict[int, str],
]:
    """Batch the active message window for a conversation list page.

    The window function keeps work bounded per conversation while avoiding the
    historical 2-query-per-conversation message/read-receipt N+1.
    """

    page_size = max(1, min(int(limit or ACTIVE_MESSAGE_WINDOW), MAX_MESSAGE_PAGE_SIZE))
    conversation_ids = [conversation.id for conversation in conversations]
    if not conversation_ids:
        return {}, {}, {}, {}

    ranked = (
        db.query(
            InboxMessage.id.label("message_id"),
            InboxMessage.conversation_id.label("conversation_id"),
            func.row_number().over(
                partition_by=InboxMessage.conversation_id,
                order_by=(InboxMessage.created_at.desc(), InboxMessage.id.desc()),
            ).label("row_number"),
        )
        .filter(
            InboxMessage.conversation_id.in_(conversation_ids),
            ~exists().where(
                and_(
                    InboxMessageUserState.message_id == InboxMessage.id,
                    InboxMessageUserState.user_id == user.id,
                    InboxMessageUserState.is_deleted_for_user.is_(True),
                )
            ),
        )
        .subquery()
    )

    rows = (
        db.query(InboxMessage, ranked.c.row_number)
        .options(joinedload(InboxMessage.conversation))
        .join(ranked, ranked.c.message_id == InboxMessage.id)
        .filter(ranked.c.row_number <= page_size + 1)
        .order_by(
            InboxMessage.conversation_id.asc(),
            InboxMessage.created_at.desc(),
            InboxMessage.id.desc(),
        )
        .all()
    )

    newest_first: dict[int, list[InboxMessage]] = {
        conversation_id: [] for conversation_id in conversation_ids
    }
    for message, _row_number in rows:
        newest_first.setdefault(message.conversation_id, []).append(message)

    windows: dict[int, list[InboxMessage]] = {}
    cursors: dict[int, str | None] = {}
    has_more: dict[int, bool] = {}
    all_visible_messages: list[InboxMessage] = []
    for conversation_id in conversation_ids:
        candidates = newest_first.get(conversation_id, [])
        more = len(candidates) > page_size
        page = candidates[:page_size]
        page.reverse()
        windows[conversation_id] = page
        has_more[conversation_id] = more
        cursors[conversation_id] = None
        if more and page:
            oldest = page[0]
            cursors[conversation_id] = _encode_cursor(
                {
                    "created_at": oldest.created_at.isoformat(),
                    "id": int(oldest.id),
                }
            )
        all_visible_messages.extend(page)

    statuses = message_statuses_for_user(db, all_visible_messages, user)
    return windows, cursors, has_more, statuses


def list_messages_page(
    db: Session,
    conversation: InboxConversation,
    user: User,
    *,
    limit: int = ACTIVE_MESSAGE_WINDOW,
    before: str | None = None,
) -> tuple[list[InboxMessage], str | None, bool]:
    page_size = max(1, min(int(limit or ACTIVE_MESSAGE_WINDOW), MAX_MESSAGE_PAGE_SIZE))
    query = db.query(InboxMessage).filter(
        InboxMessage.conversation_id == conversation.id,
        ~exists().where(
            and_(
                InboxMessageUserState.message_id == InboxMessage.id,
                InboxMessageUserState.user_id == user.id,
                InboxMessageUserState.is_deleted_for_user.is_(True),
            )
        ),
    )
    decoded = _decode_cursor(before)
    if decoded is not None:
        try:
            cursor_created_at = datetime.fromisoformat(str(decoded["created_at"]))
            cursor_id = int(decoded["id"])
        except (KeyError, TypeError, ValueError) as exc:
            raise ValueError("Invalid Inbox message cursor") from exc
        query = query.filter(
            or_(
                InboxMessage.created_at < cursor_created_at,
                and_(
                    InboxMessage.created_at == cursor_created_at,
                    InboxMessage.id < cursor_id,
                ),
            )
        )

    rows = (
        query.order_by(InboxMessage.created_at.desc(), InboxMessage.id.desc())
        .limit(page_size + 1)
        .all()
    )
    has_more = len(rows) > page_size
    rows = rows[:page_size]
    # API keeps the historical oldest -> newest message order.
    rows.reverse()
    next_cursor = None
    if has_more and rows:
        oldest = rows[0]
        next_cursor = _encode_cursor(
            {
                "created_at": oldest.created_at.isoformat(),
                "id": int(oldest.id),
            }
        )
    return rows, next_cursor, has_more


def message_statuses_for_user(
    db: Session,
    messages: list[InboxMessage],
    user: User,
) -> dict[int, str]:
    if not messages:
        return {}
    message_ids = [message.id for message in messages]
    receipts = (
        db.query(InboxReadReceipt)
        .filter(InboxReadReceipt.message_id.in_(message_ids))
        .all()
    )
    receipt_users: dict[int, set[int]] = {}
    for receipt in receipts:
        receipt_users.setdefault(receipt.message_id, set()).add(receipt.user_id)

    statuses: dict[int, str] = {}
    for message in messages:
        readers = receipt_users.get(message.id, set())
        if message.sender_user_id == user.id:
            if any(reader_id != user.id for reader_id in readers):
                statuses[message.id] = InboxMessageStatus.READ.value
            else:
                statuses[message.id] = message.status
        elif user.id in readers:
            statuses[message.id] = InboxMessageStatus.READ.value
        else:
            statuses[message.id] = message.status
    return statuses


def ensure_family_conversation(
    db: Session,
    *,
    family_id: int,
    title: str,
    member_user_ids: list[int],
) -> InboxConversation:
    """Synchronize one family chat through the Inbox write authority."""

    public_id = f"family_chat_{int(family_id)}"
    safe_title = (title or f"Family {family_id}").strip()[:120] or f"Family {family_id}"
    desired_members = {int(user_id) for user_id in member_user_ids if int(user_id) > 0}

    conversation = (
        db.query(InboxConversation)
        .filter(InboxConversation.public_id == public_id)
        .first()
    )
    if conversation is None:
        conversation = InboxConversation(
            public_id=public_id,
            title=safe_title,
            avatar_text=_avatar_text(safe_title),
            conversation_type=InboxConversationType.FAMILY.value,
            is_official=False,
            metadata_json={"family_id": int(family_id), "colors": DEFAULT_COLORS},
        )
        db.add(conversation)
        db.flush()

    changed = False
    existing = {item.user_id: item for item in conversation.participants}
    for user_id in desired_members:
        participant = existing.get(user_id)
        if participant is None:
            db.add(
                InboxParticipant(
                    conversation_id=conversation.id,
                    user_id=user_id,
                )
            )
            changed = True
        elif participant.is_deleted_for_user:
            participant.is_deleted_for_user = False
            db.add(participant)
            changed = True

    for user_id, participant in existing.items():
        if user_id not in desired_members and not participant.is_deleted_for_user:
            participant.is_deleted_for_user = True
            db.add(participant)
            changed = True

    if conversation.title != safe_title:
        conversation.title = safe_title
        conversation.avatar_text = _avatar_text(safe_title)
        changed = True
    if conversation.conversation_type != InboxConversationType.FAMILY.value:
        conversation.conversation_type = InboxConversationType.FAMILY.value
        changed = True
    if changed:
        conversation.updated_at = datetime.utcnow()
    db.add(conversation)
    db.commit()
    db.refresh(conversation)
    return conversation


def create_direct_conversation(db: Session, current_user: User, target_user: User) -> InboxConversation:
    _merge_duplicate_direct_conversations_for_user(db, current_user)

    existing_conversations = (
        db.query(InboxConversation)
        .join(InboxParticipant)
        .filter(
            InboxConversation.is_official.is_(False),
            InboxParticipant.user_id.in_([current_user.id, target_user.id]),
        )
        .all()
    )

    for conversation in existing_conversations:
        pair_key = _direct_pair_key(conversation)
        if pair_key == tuple(sorted([current_user.id, target_user.id])):
            if conversation.conversation_type != InboxConversationType.CHAT.value:
                conversation.conversation_type = InboxConversationType.CHAT.value
                conversation.updated_at = datetime.utcnow()
                db.add(conversation)
                db.commit()
                db.refresh(conversation)
            return conversation

    title = _display_name(target_user)
    conversation = InboxConversation(
        public_id=_public_id("chat"),
        title=title,
        avatar_text=_avatar_text(title),
        conversation_type=InboxConversationType.CHAT.value,
        metadata_json={"colors": DEFAULT_COLORS, "avatar_url": target_user.avatar_url},
    )
    db.add(conversation)
    db.flush()
    db.add_all([
        InboxParticipant(conversation_id=conversation.id, user_id=current_user.id),
        InboxParticipant(conversation_id=conversation.id, user_id=target_user.id),
    ])
    db.commit()
    db.refresh(conversation)
    return conversation


def send_message(
    db: Session,
    conversation: InboxConversation,
    sender: User,
    text: str,
    message_type: str = InboxMessageType.TEXT.value,
    reply_to_text: str | None = None,
    invite_room_name: str | None = None,
    invite_room_id: str | None = None,
    attachment_url: str | None = None,
    metadata: dict | None = None,
    source_dedupe_key: str | None = None,
) -> InboxMessage:
    safe_text = text.strip()
    clean_dedupe_key = (source_dedupe_key or "").strip() or None

    if clean_dedupe_key is not None:
        existing = (
            db.query(InboxMessage)
            .filter(InboxMessage.source_dedupe_key == clean_dedupe_key)
            .first()
        )
        if existing is not None:
            return existing

    message_metadata = dict(metadata or {})
    if message_type == InboxMessageType.ROOM_INVITE.value:
        if invite_room_name:
            message_metadata["invite_room_name"] = invite_room_name
        if invite_room_id:
            message_metadata["invite_room_id"] = invite_room_id
        message_metadata["action"] = "join_room"

    message = InboxMessage(
        public_id=_public_id("msg"),
        source_dedupe_key=clean_dedupe_key,
        conversation_id=conversation.id,
        sender_user_id=sender.id,
        sender_name=_display_name(sender),
        message_type=message_type,
        text=safe_text,
        status=InboxMessageStatus.SENT.value,
        reply_to_text=reply_to_text,
        invite_room_name=invite_room_name,
        attachment_url=attachment_url,
        metadata_json=message_metadata or None,
    )
    if _disappearing_mode_enabled(conversation):
        expires_at = datetime.utcnow() + timedelta(
            seconds=_disappearing_ttl_seconds(conversation)
        )
        message_metadata = dict(message.metadata_json or {})
        message_metadata["disappearing"] = True
        message_metadata["expires_at"] = _utc_iso_z(expires_at)
        message.metadata_json = message_metadata

    if _secret_drift_enabled(conversation):
        message_metadata = dict(message.metadata_json or {})
        message_metadata["secret_drift"] = True
        message_metadata["secret_drift_created_at"] = _utc_iso_z(datetime.utcnow())
        message.metadata_json = message_metadata

        conversation_metadata = _conversation_metadata(conversation)
        conversation_metadata["secret_drift_closed_by"] = []
        conversation_metadata["secret_drift_last_message_at"] = _utc_iso_z(
            datetime.utcnow()
        )
        conversation.metadata_json = conversation_metadata

    conversation.updated_at = datetime.utcnow()
    if message_type == InboxMessageType.ROOM_INVITE.value:
        conversation.current_room_name = invite_room_name
        conversation.room_public_id = invite_room_id
    db.add(message)
    for participant in conversation.participants:
        if participant.user_id != sender.id:
            participant.unread_count += 1

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        if clean_dedupe_key is None:
            raise
        existing = (
            db.query(InboxMessage)
            .filter(InboxMessage.source_dedupe_key == clean_dedupe_key)
            .first()
        )
        if existing is None:
            raise
        return existing

    db.refresh(message)
    return message


def send_room_invite_message(
    db: Session,
    sender: User,
    target_user: User,
    room_name: str,
    room_public_id: str | None = None,
    room_language: str | None = None,
    mode_title: str | None = None,
) -> tuple[InboxConversation, InboxMessage]:
    conversation = create_direct_conversation(db, sender, target_user)
    safe_room_name = room_name.strip()
    inviter_name = _display_name(sender)
    message_text = f"{inviter_name} invited you to {safe_room_name}."
    metadata = {
        "action": "join_room",
        "room_name": safe_room_name,
        "room_public_id": room_public_id,
        "invite_room_id": room_public_id,
        "room_language": room_language or "Telugu",
        "mode_title": mode_title or "Open",
        "inviter_user_id": sender.id,
        "inviter_public_user_id": sender.public_user_id,
    }
    message = send_message(
        db=db,
        conversation=conversation,
        sender=sender,
        text=message_text,
        message_type=InboxMessageType.ROOM_INVITE.value,
        invite_room_name=safe_room_name,
        invite_room_id=room_public_id,
        metadata=metadata,
    )
    return conversation, message


def send_team_system_message(db: Session, user: User, text: str) -> InboxMessage:
    conversation = ensure_team_conversation(db, user)
    message = InboxMessage(public_id=_public_id("system"), conversation_id=conversation.id, sender_user_id=None, sender_name=OFFICIAL_TEAM_NAME, message_type=InboxMessageType.SYSTEM.value, text=text, status=InboxMessageStatus.READ.value)
    conversation.updated_at = datetime.utcnow()
    db.add(message)
    db.commit()
    db.refresh(message)
    return message


def update_conversation_state(
    db: Session,
    conversation: InboxConversation,
    user: User,
    is_muted: bool | None = None,
    is_pinned: bool | None = None,
    is_archived: bool | None = None,
    is_locked: bool | None = None,
    is_blocked: bool | None = None,
) -> InboxConversation:
    participant = next(
        (item for item in conversation.participants if item.user_id == user.id),
        None,
    )
    if participant is None:
        raise ValueError("Conversation participant not found")
    if is_muted is not None:
        participant.is_muted = is_muted
    if is_pinned is not None:
        participant.is_pinned = is_pinned
    if is_archived is not None:
        participant.is_archived = is_archived
    if is_locked is not None and not conversation.is_official:
        conversation.is_locked = is_locked
    if is_blocked is not None and not conversation.is_official:
        conversation.is_blocked = is_blocked
    db.add(participant)
    db.add(conversation)
    db.commit()
    db.refresh(conversation)
    return conversation

def update_message(db: Session, conversation: InboxConversation, message_public_id: str, reaction: str | None = None, is_starred: bool | None = None) -> InboxMessage | None:
    message = db.query(InboxMessage).filter(InboxMessage.public_id == message_public_id, InboxMessage.conversation_id == conversation.id).first()
    if not message:
        return None
    if reaction is not None:
        message.reaction = reaction
    if is_starred is not None:
        message.is_starred = is_starred
    db.commit()
    db.refresh(message)
    return message


def delete_message(db: Session, conversation: InboxConversation, message_public_id: str) -> bool:
    message = db.query(InboxMessage).filter(InboxMessage.public_id == message_public_id, InboxMessage.conversation_id == conversation.id).first()
    if not message:
        return False
    db.delete(message)
    db.commit()
    return True


def create_report(db: Session, conversation: InboxConversation, reporter: User, reason: str) -> InboxReport:
    snapshot = [message_to_dict(message, reporter) for message in conversation.messages[-30:]]
    report = InboxReport(public_id=_public_id("report"), conversation_id=conversation.id, reporter_user_id=reporter.id, reported_user_name=conversation.title, reason=reason.strip(), snapshot_json=snapshot, status=InboxReportStatus.PENDING_CS_REVIEW.value)
    db.add(report)
    db.commit()
    db.refresh(report)
    send_team_system_message(db, reporter, "Report submitted. CS will review the conversation snapshot and escalate if action is needed.")
    return report


def list_report_tasks(db: Session) -> list[InboxReport]:
    return db.query(InboxReport).order_by(InboxReport.created_at.desc()).all()


def decide_report(db: Session, report: InboxReport, accepted: bool, cs_note: str | None = None) -> InboxReport:
    report.cs_note = cs_note
    if accepted:
        report.status = InboxReportStatus.ACCEPTED_ESCALATED.value
        report.monitor_action = "Pending Monitor action"
        send_team_system_message(db, report.reporter, f"Report successful. {report.reported_user_name} has been sent to Monitor team for punishment review.")
    else:
        report.status = InboxReportStatus.REJECTED_BY_CS.value
        send_team_system_message(db, report.reporter, f"Report failed. CS reviewed your report about {report.reported_user_name}, but there was not enough evidence to punish the user.")
    db.commit()
    db.refresh(report)
    return report


def apply_monitor_action(db: Session, report: InboxReport, action_label: str) -> InboxReport:
    report.status = InboxReportStatus.MONITOR_ACTION_TAKEN.value
    report.monitor_action = action_label
    send_team_system_message(db, report.reporter, f"Report successful. {report.reported_user_name} has been punished by Monitor team: {action_label}.")
    db.commit()
    db.refresh(report)
    return report


def _chat_streak_participant_user_ids(conversation: InboxConversation) -> set[int]:
    if conversation.is_official:
        return set()
    return {
        participant.user_id
        for participant in conversation.participants
        if participant.user_id is not None
    }


def _chat_streak_day(value: datetime):
    # Current app-local day basis. Later this should use each user's saved timezone.
    return (value + timedelta(hours=5, minutes=30)).date()


def _chat_streak_today():
    return _chat_streak_day(datetime.utcnow())


def _two_way_streak_days(
    conversation: InboxConversation,
    messages: list[InboxMessage],
) -> list:
    participant_ids = _chat_streak_participant_user_ids(conversation)
    if len(participant_ids) != 2:
        return []

    senders_by_day: dict = {}
    for message in messages:
        if message.created_at is None or message.sender_user_id is None:
            continue
        if message.sender_user_id not in participant_ids:
            continue
        day = _chat_streak_day(message.created_at)
        senders_by_day.setdefault(day, set()).add(message.sender_user_id)

    return sorted(
        [day for day, sender_ids in senders_by_day.items() if participant_ids.issubset(sender_ids)],
        reverse=True,
    )


def _chat_streak_count(conversation: InboxConversation, messages: list[InboxMessage]) -> int:
    two_way_days = _two_way_streak_days(conversation, messages)
    if not two_way_days:
        return 0

    today = _chat_streak_today()
    latest_day = two_way_days[0]
    if latest_day < today - timedelta(days=1):
        return 0

    streak = 1
    expected_day = latest_day - timedelta(days=1)
    for day in two_way_days[1:]:
        if day == expected_day:
            streak += 1
            expected_day -= timedelta(days=1)
            continue
        if day < expected_day:
            break
    return streak


def _chat_streak_active_today(conversation: InboxConversation, messages: list[InboxMessage]) -> bool:
    return _chat_streak_today() in _two_way_streak_days(conversation, messages)


def mark_messages_delivered_for_user(
    db: Session,
    conversation: InboxConversation,
    user: User,
) -> list[InboxMessage]:
    changed: list[InboxMessage] = []
    for message in conversation.messages:
        if message.sender_user_id is None:
            continue
        if message.sender_user_id == user.id:
            continue
        if message.status == InboxMessageStatus.SENT.value:
            message.status = InboxMessageStatus.DELIVERED.value
            changed.append(message)
    if changed:
        db.commit()
        for message in changed:
            db.refresh(message)
    return changed


def mark_messages_read_for_user(
    db: Session,
    conversation: InboxConversation,
    user: User,
) -> list[InboxMessage]:
    participant = next(
        (item for item in conversation.participants if item.user_id == user.id),
        None,
    )
    if participant is None:
        return []

    latest = (
        db.query(InboxMessage)
        .filter(InboxMessage.conversation_id == conversation.id)
        .order_by(InboxMessage.id.desc())
        .first()
    )
    if latest is None:
        if participant.unread_count:
            participant.unread_count = 0
            db.commit()
        return []

    # The last-read pointer makes historical reads O(1); explicit receipts are
    # kept for the bounded active window used by sender/read-receipt UI.
    recent = (
        db.query(InboxMessage)
        .filter(
            InboxMessage.conversation_id == conversation.id,
            InboxMessage.id <= latest.id,
            or_(
                InboxMessage.sender_user_id.is_(None),
                InboxMessage.sender_user_id != user.id,
            ),
        )
        .order_by(InboxMessage.id.desc())
        .limit(READ_RECEIPT_WINDOW)
        .all()
    )
    message_ids = [message.id for message in recent]
    existing = set()
    if message_ids:
        existing = {
            receipt.message_id
            for receipt in db.query(InboxReadReceipt)
            .filter(
                InboxReadReceipt.user_id == user.id,
                InboxReadReceipt.message_id.in_(message_ids),
            )
            .all()
        }
    read_at = datetime.utcnow()
    for message in recent:
        if message.id not in existing:
            db.add(
                InboxReadReceipt(
                    message_id=message.id,
                    conversation_id=conversation.id,
                    user_id=user.id,
                    read_at=read_at,
                )
            )

    participant.unread_count = 0
    participant.last_read_message_id = latest.id
    db.add(participant)
    db.commit()
    return list(reversed(recent))



def _conversation_metadata(conversation: InboxConversation) -> dict:
    return dict(conversation.metadata_json or {})


def _disappearing_mode_enabled(conversation: InboxConversation) -> bool:
    metadata = _conversation_metadata(conversation)
    return metadata.get("disappearing_mode_enabled") is True


def _disappearing_ttl_seconds(conversation: InboxConversation) -> int:
    metadata = _conversation_metadata(conversation)
    raw = metadata.get("disappearing_ttl_seconds") or 86400
    try:
        value = int(raw)
    except (TypeError, ValueError):
        value = 86400
    return max(60, min(value, 604800))


def _message_expires_at(message: InboxMessage) -> datetime | None:
    metadata = message.metadata_json or {}
    raw = metadata.get("expires_at")
    if raw is None:
        return None
    if isinstance(raw, datetime):
        return raw
    if isinstance(raw, str):
        cleaned = raw.removesuffix("Z")
        try:
            return datetime.fromisoformat(cleaned)
        except ValueError:
            return None
    return None


def _is_message_expired(message: InboxMessage) -> bool:
    expires_at = _message_expires_at(message)
    return expires_at is not None and datetime.utcnow() >= expires_at


def _visible_messages(messages: list[InboxMessage]) -> list[InboxMessage]:
    return [message for message in messages if not _is_message_expired(message)]


def set_disappearing_mode(
    db: Session,
    conversation: InboxConversation,
    enabled: bool,
    ttl_seconds: int = 86400,
) -> InboxConversation:
    metadata = _conversation_metadata(conversation)
    metadata["disappearing_mode_enabled"] = bool(enabled)
    metadata["disappearing_ttl_seconds"] = max(60, min(int(ttl_seconds or 86400), 604800))
    conversation.metadata_json = metadata
    conversation.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(conversation)
    return conversation




def _conversation_metadata(conversation: InboxConversation) -> dict:
    return dict(conversation.metadata_json or {})


def _secret_drift_enabled(conversation: InboxConversation) -> bool:
    metadata = _conversation_metadata(conversation)
    return metadata.get("secret_drift_enabled") is True


def _is_secret_drift_message(message: InboxMessage) -> bool:
    metadata = message.metadata_json or {}
    return metadata.get("secret_drift") is True


def clear_secret_drift_messages(
    db: Session,
    conversation: InboxConversation,
) -> int:
    cleared_count = 0
    for message in list(conversation.messages):
        if _is_secret_drift_message(message):
            db.delete(message)
            cleared_count += 1

    if cleared_count > 0:
        metadata = _conversation_metadata(conversation)
        metadata["secret_drift_closed_by"] = []
        metadata["secret_drift_last_cleared_at"] = _utc_iso_z(datetime.utcnow())
        conversation.metadata_json = metadata
        conversation.updated_at = datetime.utcnow()
        db.add(conversation)

    return cleared_count


def set_secret_drift_mode(
    db: Session,
    conversation: InboxConversation,
    enabled: bool,
    started_by_user_id: int | None = None,
) -> InboxConversation:
    metadata = _conversation_metadata(conversation)

    if enabled:
        metadata["secret_drift_enabled"] = True
        metadata["secret_drift_closed_by"] = []
        metadata["secret_drift_started_by"] = started_by_user_id
        metadata["secret_drift_started_at"] = _utc_iso_z(datetime.utcnow())
        conversation.metadata_json = metadata
        conversation.updated_at = datetime.utcnow()
        db.add(conversation)
        db.commit()
        db.refresh(conversation)
        return conversation

    # Turning Secret Drift OFF is a no-trace clear for all Secret Drift messages.
    clear_secret_drift_messages(db, conversation)
    metadata = _conversation_metadata(conversation)
    metadata["secret_drift_enabled"] = False
    metadata["secret_drift_closed_by"] = []
    metadata["secret_drift_ended_at"] = _utc_iso_z(datetime.utcnow())
    conversation.metadata_json = metadata
    conversation.updated_at = datetime.utcnow()
    db.add(conversation)
    db.commit()
    db.refresh(conversation)
    return conversation


def mark_secret_drift_open(
    db: Session,
    conversation: InboxConversation,
    user: User,
) -> InboxConversation:
    if not _secret_drift_enabled(conversation):
        return conversation
    metadata = _conversation_metadata(conversation)
    closed_by = set(metadata.get("secret_drift_closed_by") or [])
    if user.id in closed_by:
        closed_by.discard(user.id)
        metadata["secret_drift_closed_by"] = sorted(closed_by)
        conversation.metadata_json = metadata
        conversation.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(conversation)
    return conversation


def mark_secret_drift_closed_and_clear(
    db: Session,
    conversation: InboxConversation,
    user: User,
) -> bool:
    if not _secret_drift_enabled(conversation):
        return False

    participant_ids = set(participant_user_ids(conversation))
    if len(participant_ids) < 2:
        return False

    metadata = _conversation_metadata(conversation)
    closed_by = set(metadata.get("secret_drift_closed_by") or [])
    closed_by.add(user.id)
    closed_by = closed_by.intersection(participant_ids)

    metadata["secret_drift_closed_by"] = sorted(closed_by)
    metadata["secret_drift_last_closed_at"] = _utc_iso_z(datetime.utcnow())
    conversation.metadata_json = metadata
    conversation.updated_at = datetime.utcnow()
    db.add(conversation)

    should_clear = participant_ids.issubset(closed_by)

    if should_clear:
        clear_secret_drift_messages(db, conversation)
        metadata = _conversation_metadata(conversation)
        metadata["secret_drift_enabled"] = False
        metadata["secret_drift_closed_by"] = []
        metadata["secret_drift_last_cleared_at"] = _utc_iso_z(datetime.utcnow())
        metadata["secret_drift_auto_ended_at"] = _utc_iso_z(datetime.utcnow())
        conversation.metadata_json = metadata
        conversation.updated_at = datetime.utcnow()
        db.add(conversation)

    db.commit()
    db.refresh(conversation)
    return should_clear



def message_to_dict(
    message: InboxMessage,
    current_user: User | None,
    *,
    status_override: str | None = None,
) -> dict:
    metadata = message.metadata_json or {}
    invite_room_id = metadata.get("invite_room_id") or metadata.get("room_public_id") or message.conversation.room_public_id
    media_expired = metadata.get("media_expired") is True
    return {
        "id": message.public_id,
        "sender": message.sender_name,
        "text": message.text,
        "time": _time_label(message.created_at),
        "is_mine": current_user is not None and message.sender_user_id == current_user.id,
        "type": message.message_type,
        "status": status_override or message.status,
        "reaction": message.reaction,
        "reply_to_text": message.reply_to_text,
        "is_starred": message.is_starred,
        "is_forwarded": message.is_forwarded,
        "invite_room_name": message.invite_room_name or metadata.get("invite_room_name") or metadata.get("room_name"),
        "invite_room_id": invite_room_id,
        "love_bond_request_id": metadata.get("love_bond_request_id"),
        "love_bond_card_name": metadata.get("love_bond_card_name") or metadata.get("card_name"),
        "love_bond_status": metadata.get("love_bond_status") or metadata.get("status"),
        "attachment_url": message.attachment_url or metadata.get("expired_media_url"),
        "media_expired": media_expired,
        "expired_media_url": metadata.get("expired_media_url"),
        "local_first_allowed": bool(metadata.get("local_first_allowed")) or media_expired,
        "created_at": _utc_iso_z(message.created_at),
    }


def _utc_iso_z(value: datetime | None) -> str | None:
    if value is None:
        return None
    return value.replace(tzinfo=None).isoformat(timespec="seconds") + "Z"




def conversation_to_dict(
    conversation: InboxConversation,
    current_user: User,
    *,
    db: Session | None = None,
    participant: InboxParticipant | None = None,
    messages: list[InboxMessage] | None = None,
    messages_next_cursor: str | None = None,
    has_older_messages: bool | None = None,
    status_overrides: dict[int, str] | None = None,
    include_messages: bool = True,
) -> dict:
    participant = participant or next(
        (item for item in conversation.participants if item.user_id == current_user.id),
        None,
    )
    if messages is None:
        if db is not None:
            messages, messages_next_cursor, has_older_messages = list_messages_page(
                db,
                conversation,
                current_user,
                limit=ACTIVE_MESSAGE_WINDOW,
            )
        else:
            # Compatibility-only fallback; all public list/detail routes pass
            # a DB session and therefore never materialize unbounded history.
            messages = list(conversation.messages)[-ACTIVE_MESSAGE_WINDOW:]
            has_older_messages = len(conversation.messages) > len(messages)

    messages = _visible_messages(list(messages))
    last_message = messages[-1] if messages else None
    statuses = (
        status_overrides
        if status_overrides is not None
        else (
            message_statuses_for_user(db, messages, current_user)
            if db is not None
            else {}
        )
    )
    metadata = conversation.metadata_json or {}
    other_user = _other_participant_user(conversation, current_user)
    uses_live_user_profile = not conversation.is_official and other_user is not None
    title = _display_name(other_user) if uses_live_user_profile else conversation.title
    avatar_url = other_user.avatar_url if uses_live_user_profile else metadata.get("avatar_url")
    streak_count = _chat_streak_count(conversation, messages)
    streak_active_today = _chat_streak_active_today(conversation, messages)
    other_user_online = inbox_ws_manager.is_user_online(
        other_user.id if other_user is not None else None
    )
    last_seen_at = inbox_ws_manager.last_seen_at(
        other_user.id if other_user is not None else None
    )
    if last_seen_at is None and other_user is not None:
        last_seen_at = (
            getattr(other_user, "last_seen_at", None)
            or getattr(other_user, "last_login_at", None)
        )
    last_seen_text = "online" if other_user_online else "offline"

    return {
        "id": conversation.public_id,
        "title": title,
        "subtitle": last_message.text if last_message else "No messages yet",
        "time": _time_label(conversation.updated_at),
        "avatar_text": _avatar_text(title),
        "avatar_url": avatar_url,
        "type": conversation.conversation_type,
        "unread_count": participant.unread_count if participant else 0,
        "is_online": other_user_online,
        "last_seen_text": last_seen_text,
        "last_seen_at": _utc_iso_z(last_seen_at),
        "colors": metadata.get("colors") or DEFAULT_COLORS,
        "messages": [
            message_to_dict(
                message,
                current_user,
                status_override=statuses.get(message.id),
            )
            for message in messages
        ] if include_messages else [],
        "messages_next_cursor": messages_next_cursor if include_messages else None,
        "has_older_messages": bool(has_older_messages) if include_messages else False,
        "current_room_name": conversation.current_room_name,
        "current_room_id": conversation.room_public_id,
        "is_locked_by_backend": conversation.is_locked,
        "is_blocked": conversation.is_blocked,
        "is_muted": participant.is_muted if participant else False,
        "is_pinned": participant.is_pinned if participant else False,
        "is_archived": participant.is_archived if participant else False,
        "chat_streak_count": streak_count,
        "chat_streak_active_today": streak_active_today,
        "secret_drift_enabled": _secret_drift_enabled(conversation),
    }

def report_to_dict(report: InboxReport) -> dict:
    return {"id": report.public_id, "reported_conversation_id": report.conversation.public_id, "reported_user_name": report.reported_user_name, "reporter_name": _display_name(report.reporter), "reason": report.reason, "snapshot": report.snapshot_json, "created_at_label": _time_label(report.created_at), "status": report.status, "cs_note": report.cs_note, "monitor_action": report.monitor_action}