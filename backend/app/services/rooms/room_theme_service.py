from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.room import Room
from app.models.room_participant import RoomParticipant
from app.models.room_theme import RoomTheme, RoomThemeOwnershipType, RoomThemeReview, RoomThemeReviewStatus, UserRoomThemeInventory
from app.models.user import User
from app.schemas.room_theme import RoomThemeResponse, RoomThemeReviewResponse
from app.services.role_service import get_user_roles

_BUILT_IN_THEMES = [
    {
        "theme_id": "default",
        "name": "Default Pearl",
        "ownership_type": RoomThemeOwnershipType.FREE.value,
        "price_coins": 0,
        "asset_path": "assets/images/room_backgrounds/default/default_pearl.webp",
        "accent": "#12C7B7",
        "overlay_opacity": 42,
        "is_default": True,
    },
    {
        "theme_id": "midnight_live",
        "name": "Midnight Live",
        "ownership_type": RoomThemeOwnershipType.FREE.value,
        "price_coins": 0,
        "asset_path": "assets/images/room_backgrounds/default/midnight_live.webp",
        "accent": "#6D5DF6",
        "overlay_opacity": 48,
        "is_default": False,
    },
    {
        "theme_id": "royal_stage",
        "name": "Royal Stage",
        "ownership_type": RoomThemeOwnershipType.PURCHASED.value,
        "price_coins": 250_000,
        "asset_path": "assets/images/room_backgrounds/store/royal_stage.webp",
        "accent": "#C99A3B",
        "overlay_opacity": 45,
        "is_default": False,
    },
    {
        "theme_id": "neon_vibe_room",
        "name": "Neon Vibe Room",
        "ownership_type": RoomThemeOwnershipType.PURCHASED.value,
        "price_coins": 500_000,
        "asset_path": "assets/images/room_backgrounds/store/neon_vibe_room.webp",
        "accent": "#E84C72",
        "overlay_opacity": 44,
        "is_default": False,
    },
]


def _role_values(user: User) -> set[str]:
    return {role.value if hasattr(role, "value") else str(role) for role in get_user_roles(user)}


def can_manage_room(db: Session, room: Room, user: User) -> bool:
    if room.owner_user_id == user.id or bool(_role_values(user) & {"founder_owner", "owner"}):
        return True
    participant = db.query(RoomParticipant).filter(RoomParticipant.room_id == room.id, RoomParticipant.user_id == user.id).first()
    return bool(participant and participant.is_room_admin)


def can_review_custom_background(user: User) -> bool:
    return bool(_role_values(user) & {"founder_owner", "owner", "superadmin", "admin", "monitor", "cs", "agency_owner"})


def seed_default_room_themes(db: Session) -> None:
    for item in _BUILT_IN_THEMES:
        theme = db.query(RoomTheme).filter(RoomTheme.theme_id == item["theme_id"]).first()
        if theme is None:
            theme = RoomTheme(**item)
            db.add(theme)
        else:
            for key, value in item.items():
                setattr(theme, key, value)
            theme.is_active = True
    db.flush()


def _is_owned(db: Session, user_id: int, theme: RoomTheme) -> bool:
    if theme.ownership_type in {RoomThemeOwnershipType.FREE.value, RoomThemeOwnershipType.CUSTOM.value}:
        return True
    return db.query(UserRoomThemeInventory.id).filter(UserRoomThemeInventory.user_id == user_id, UserRoomThemeInventory.theme_id == theme.theme_id).first() is not None


def theme_payload(db: Session, theme: RoomTheme, user_id: int | None = None) -> RoomThemeResponse:
    return RoomThemeResponse(
        theme_id=theme.theme_id,
        name=theme.name,
        ownership_type=theme.ownership_type,
        price_coins=theme.price_coins,
        image_url=theme.image_url,
        thumbnail_url=theme.thumbnail_url,
        asset_path=theme.asset_path,
        accent=theme.accent,
        overlay_opacity=max(min(int(theme.overlay_opacity or 42), 100), 0) / 100,
        is_default=theme.is_default,
        is_owned=True if user_id is None else _is_owned(db, user_id, theme),
        is_active=theme.is_active,
    )


def list_store_room_themes(db: Session, user: User) -> list[RoomThemeResponse]:
    seed_default_room_themes(db)
    db.commit()
    themes = db.query(RoomTheme).filter(RoomTheme.is_active.is_(True)).order_by(RoomTheme.is_default.desc(), RoomTheme.price_coins.asc(), RoomTheme.id.asc()).all()
    return [theme_payload(db, theme, user.id) for theme in themes]


def _theme_or_404(db: Session, theme_id: str) -> RoomTheme:
    seed_default_room_themes(db)
    theme = db.query(RoomTheme).filter(RoomTheme.theme_id == theme_id, RoomTheme.is_active.is_(True)).first()
    if theme is None:
        raise HTTPException(status_code=404, detail="Room background theme not found")
    return theme


def room_theme_purchase_quote(
    db: Session,
    *,
    user_id: int,
    theme_id: str,
) -> dict:
    theme = _theme_or_404(db, theme_id)
    return {
        "theme_id": theme.theme_id,
        "name": theme.name,
        "ownership_type": theme.ownership_type,
        "price_coins": int(theme.price_coins or 0),
        "is_owned": _is_owned(db, user_id, theme),
    }


def grant_room_theme_inventory(
    db: Session,
    *,
    user_id: int,
    theme_id: str,
    source: str,
) -> RoomThemeResponse:
    theme = _theme_or_404(db, theme_id)
    existing = (
        db.query(UserRoomThemeInventory)
        .filter(
            UserRoomThemeInventory.user_id == user_id,
            UserRoomThemeInventory.theme_id == theme.theme_id,
        )
        .first()
    )
    if existing is None:
        db.add(
            UserRoomThemeInventory(
                user_id=user_id,
                theme_id=theme.theme_id,
                source=(source or theme.ownership_type or "purchase")[:40],
            )
        )
        db.commit()
    return theme_payload(db, theme, user_id)


def apply_room_theme(db: Session, room: Room, user: User, theme_id: str) -> Room:
    if not can_manage_room(db, room, user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the channel host/admin or Owner can change room background")
    theme = _theme_or_404(db, theme_id)
    if not _is_owned(db, user.id, theme):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Purchase this background before applying it")
    room.background_theme_id = theme.theme_id
    room.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(room)
    return room


def submit_custom_room_background(db: Session, user: User, image_url: str, thumbnail_url: str | None = None, room: Room | None = None) -> RoomThemeReviewResponse:
    proposed_theme_id = f"custom_{user.id}_{uuid4().hex[:12]}"
    review = RoomThemeReview(
        review_public_id=f"RTV{uuid4().hex[:14].upper()}",
        submitter_user_id=user.id,
        room_id=room.id if room else None,
        room_public_id=room.room_public_id if room else None,
        image_url=image_url.strip(),
        thumbnail_url=thumbnail_url.strip() if thumbnail_url else None,
        proposed_theme_id=proposed_theme_id,
        status=RoomThemeReviewStatus.PENDING.value,
    )
    db.add(review)
    db.commit()
    db.refresh(review)
    return review_payload(review)


def review_payload(review: RoomThemeReview) -> RoomThemeReviewResponse:
    return RoomThemeReviewResponse(
        review_public_id=review.review_public_id,
        submitter_user_id=review.submitter_user_id,
        room_public_id=review.room_public_id,
        image_url=review.image_url,
        thumbnail_url=review.thumbnail_url,
        proposed_theme_id=review.proposed_theme_id,
        status=review.status,
        review_note=review.review_note,
        reviewed_by_user_id=review.reviewed_by_user_id,
        reviewed_at=review.reviewed_at,
        created_at=review.created_at,
    )


def list_pending_custom_background_reviews(db: Session, reviewer: User) -> list[RoomThemeReviewResponse]:
    if not can_review_custom_background(reviewer):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No permission to review custom room backgrounds")
    rows = db.query(RoomThemeReview).filter(RoomThemeReview.status == RoomThemeReviewStatus.PENDING.value).order_by(RoomThemeReview.created_at.asc()).limit(200).all()
    return [review_payload(row) for row in rows]


def decide_custom_background_review(db: Session, reviewer: User, review_public_id: str, status_value: str, review_note: str) -> RoomThemeReviewResponse:
    if not can_review_custom_background(reviewer):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No permission to review custom room backgrounds")
    review = db.query(RoomThemeReview).filter(RoomThemeReview.review_public_id == review_public_id).first()
    if review is None:
        raise HTTPException(status_code=404, detail="Custom background review task not found")
    if review.status != RoomThemeReviewStatus.PENDING.value:
        raise HTTPException(status_code=400, detail="Review task already completed")
    now = datetime.utcnow()
    review.status = status_value
    review.review_note = review_note
    review.reviewed_by_user_id = reviewer.id
    review.reviewed_at = now
    if status_value == RoomThemeReviewStatus.APPROVED.value:
        theme = RoomTheme(
            theme_id=review.proposed_theme_id,
            name="Custom Background",
            ownership_type=RoomThemeOwnershipType.CUSTOM.value,
            price_coins=0,
            image_url=review.image_url,
            thumbnail_url=review.thumbnail_url,
            accent="#12C7B7",
            overlay_opacity=42,
            is_active=True,
            is_default=False,
            created_by_user_id=review.submitter_user_id,
        )
        db.add(theme)
        if db.query(UserRoomThemeInventory.id).filter(UserRoomThemeInventory.user_id == review.submitter_user_id, UserRoomThemeInventory.theme_id == review.proposed_theme_id).first() is None:
            db.add(UserRoomThemeInventory(user_id=review.submitter_user_id, theme_id=review.proposed_theme_id, source="custom_approved"))
        if review.room_id is not None:
            room = db.query(Room).filter(Room.id == review.room_id).first()
            if room is not None:
                room.background_theme_id = review.proposed_theme_id
                room.updated_at = now
    db.commit()
    db.refresh(review)
    return review_payload(review)
