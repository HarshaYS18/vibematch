#!/usr/bin/env python3
"""Deterministic, idempotent development seed for FunKey.

The script is intentionally forbidden outside explicit development/test
environments and never fabricates Economy value. Seed wallets start at zero.
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))

from app.core.config import settings  # noqa: E402
from app.database import SessionLocal  # noqa: E402
from app.models.economy import UserWallet  # noqa: E402
from app.models.economy_stats import FamilyEconomyStats, FamilyMemberStats  # noqa: E402
from app.models.event_outbox import EventOutbox  # noqa: E402
from app.models.game import GameDefinition  # noqa: E402
from app.models.inbox import (  # noqa: E402
    InboxConversation,
    InboxMessage,
    InboxParticipant,
)
from app.models.room import Room  # noqa: E402
from app.models.user import User  # noqa: E402
from app.models.vibe import VibePost  # noqa: E402


MANIFEST = ROOT / "dev" / "seed" / "seed-v1.json"
ALLOWED_ENVS = {"development", "dev", "local", "test", "testing"}


def _assert_safe_environment() -> None:
    env = settings.APP_ENV.strip().lower()
    if env not in ALLOWED_ENVS:
        raise SystemExit(
            f"Refusing development seed in APP_ENV={settings.APP_ENV!r}. "
            f"Allowed: {sorted(ALLOWED_ENVS)}"
        )
    if os.getenv("FUNKEY_DEV_SEED_CONFIRM", "").strip() != "YES":
        raise SystemExit(
            "Set FUNKEY_DEV_SEED_CONFIRM=YES to acknowledge that this is a "
            "development-only database mutation."
        )


def _first(db, model, **filters):
    return db.query(model).filter_by(**filters).first()


def seed() -> None:
    _assert_safe_environment()
    payload = json.loads(MANIFEST.read_text(encoding="utf-8"))
    db = SessionLocal()
    try:
        users: list[User] = []
        for item in payload["users"]:
            user = _first(db, User, public_user_id=item["public_user_id"])
            if user is None:
                user = User(
                    public_user_id=item["public_user_id"],
                    username=item["username"],
                    display_name=item["display_name"],
                    is_active=True,
                    is_banned=False,
                    is_protected=False,
                )
                db.add(user)
                db.flush()
            users.append(user)

        room_data = payload["room"]
        room = _first(db, Room, room_public_id=room_data["room_public_id"])
        if room is None:
            room = Room(
                room_public_id=room_data["room_public_id"],
                owner_user_id=users[0].id,
                name=room_data["name"],
                subtitle="Deterministic local seed room",
                language=room_data["language"],
                mode="Open",
                room_type="Chat",
                online_count=0,
                trending_score=0,
                is_active=True,
            )
            db.add(room)

        conversation_data = payload["conversation"]
        conversation = _first(
            db,
            InboxConversation,
            public_id=conversation_data["public_id"],
        )
        if conversation is None:
            conversation = InboxConversation(
                public_id=conversation_data["public_id"],
                title=conversation_data["title"],
                avatar_text="DEV",
                conversation_type="chat",
                is_official=False,
            )
            db.add(conversation)
            db.flush()

        for user in users[:2]:
            participant = (
                db.query(InboxParticipant)
                .filter(
                    InboxParticipant.conversation_id == conversation.id,
                    InboxParticipant.user_id == user.id,
                )
                .first()
            )
            if participant is None:
                db.add(
                    InboxParticipant(
                        conversation_id=conversation.id,
                        user_id=user.id,
                        unread_count=0,
                    )
                )

        seeded_messages = (
            ("dev-message-001", users[0], "Welcome to the deterministic FunKey dev seed."),
            ("dev-message-002", users[1], "This message can be recreated safely."),
        )
        for public_id, sender, text in seeded_messages:
            if _first(db, InboxMessage, public_id=public_id) is None:
                db.add(
                    InboxMessage(
                        public_id=public_id,
                        source_dedupe_key=f"dev-seed:{public_id}",
                        conversation_id=conversation.id,
                        sender_user_id=sender.id,
                        sender_name=sender.display_name or sender.username or "Dev User",
                        message_type="text",
                        text=text,
                        status="sent",
                    )
                )

        vibe_caption = "[dev-seed-v1] Welcome to FunKey Vibes"
        vibe = (
            db.query(VibePost)
            .filter(
                VibePost.author_user_id == users[2].id,
                VibePost.caption == vibe_caption,
            )
            .first()
        )
        if vibe is None:
            db.add(
                VibePost(
                    author_user_id=users[2].id,
                    caption=vibe_caption,
                    media_type="text",
                    comments_enabled=True,
                )
            )

        family_data = payload["family"]
        family = _first(
            db,
            FamilyEconomyStats,
            family_id=family_data["family_id"],
        )
        if family is None:
            family = FamilyEconomyStats(
                family_id=family_data["family_id"],
                family_name=family_data["family_name"],
                family_level=0,
                family_exp=0,
                member_count=2,
            )
            db.add(family)
        for index, user in enumerate(users[:2]):
            member = (
                db.query(FamilyMemberStats)
                .filter(
                    FamilyMemberStats.family_id == family_data["family_id"],
                    FamilyMemberStats.user_id == user.id,
                )
                .first()
            )
            if member is None:
                db.add(
                    FamilyMemberStats(
                        family_id=family_data["family_id"],
                        user_id=user.id,
                        family_role="owner" if index == 0 else "member",
                    )
                )

        # Economy seed is intentionally zero-value. There is no fake coin supply,
        # no ledger history and no bypass of Economy invariants.
        for user in users:
            wallet = _first(db, UserWallet, user_id=user.id)
            if wallet is None:
                db.add(
                    UserWallet(
                        user_id=user.id,
                        coin_balance=0,
                        ruby_balance=0,
                        locked_ruby_balance=0,
                        pending_withdraw_rubies=0,
                    )
                )

        game_data = payload["game"]
        game = _first(db, GameDefinition, game_key=game_data["game_key"])
        if game is None:
            db.add(
                GameDefinition(
                    game_key=game_data["game_key"],
                    display_name=game_data["display_name"],
                    category="social",
                    is_enabled=True,
                    is_coin_game=False,
                    min_app_version="1.0.0",
                    config_version=1,
                    ui_config_json="{}",
                    rules_json="{}",
                    risk_config_json="{}",
                )
            )

        # A published seed event exercises event-shaped development data without
        # causing the outbox relay to deliver synthetic work downstream.
        if _first(db, EventOutbox, event_id=payload["event_id"]) is None:
            now = datetime.now(timezone.utc)
            db.add(
                EventOutbox(
                    event_id=payload["event_id"],
                    event_type="dev.seed.completed",
                    event_version=1,
                    occurred_at=now,
                    actor_user_id=users[0].id,
                    payload={
                        "seed_id": payload["seed_id"],
                        "room_public_id": room_data["room_public_id"],
                    },
                    published_at=now,
                )
            )

        db.commit()
        print(
            "FunKey dev seed ready: "
            f"{len(users)} users, room={room_data['room_public_id']}, "
            f"family={family_data['family_id']}, game={game_data['game_key']}"
        )
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed()
