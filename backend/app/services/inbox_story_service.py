from datetime import datetime
from uuid import uuid4

from sqlalchemy.orm import Session

from app.models.cdn_media import CdnMediaLinkedEntityType, CdnMediaType
from app.models.follow import UserFollow
from app.models.inbox_story import InboxStory, InboxStoryView
from app.models.user import User
from app.services import cdn_media_service

VALID_VISIBILITY = {"everyone", "friends", "nobody"}
VALID_MEDIA_TYPES = {"image", "video"}


def _public_id() -> str:
    return f"story_{uuid4().hex[:18]}"


def _display_name(user: User | None) -> str:
    if user is None:
        return "User"
    return user.display_name or user.username or f"User {user.public_user_id}"


def _are_mutual_friends(db: Session, user_a_id: int, user_b_id: int) -> bool:
    if user_a_id == user_b_id:
        return True
    a_follows_b = db.query(UserFollow).filter(UserFollow.follower_user_id == user_a_id, UserFollow.following_user_id == user_b_id).first()
    b_follows_a = db.query(UserFollow).filter(UserFollow.follower_user_id == user_b_id, UserFollow.following_user_id == user_a_id).first()
    return a_follows_b is not None and b_follows_a is not None


def _can_view_story(db: Session, viewer: User, story: InboxStory) -> bool:
    if not story.is_active or story.expires_at <= datetime.utcnow():
        return False
    if story.owner_user_id == viewer.id:
        return True
    owner = story.owner
    if owner is None:
        return False
    visibility = story.visibility or "friends"
    if visibility == "nobody":
        return False
    if visibility == "friends":
        return _are_mutual_friends(db, viewer.id, story.owner_user_id)
    return visibility == "everyone"


def story_to_dict(db: Session, story: InboxStory, viewer: User) -> dict:
    viewed = db.query(InboxStoryView).filter(InboxStoryView.story_id == story.id, InboxStoryView.viewer_user_id == viewer.id).first() is not None
    return {
        "id": story.public_id,
        "owner_user_id": story.owner_user_id,
        "owner_name": _display_name(story.owner),
        "owner_avatar_url": story.owner.avatar_url if story.owner else None,
        "media_url": story.media_url,
        "media_type": story.media_type,
        "caption": story.caption,
        "visibility": story.visibility,
        "view_count": story.view_count,
        "is_mine": story.owner_user_id == viewer.id,
        "is_viewed": viewed,
        "created_at": story.created_at,
        "expires_at": story.expires_at,
    }


def list_visible_stories(db: Session, viewer: User) -> list[InboxStory]:
    stories = db.query(InboxStory).filter(InboxStory.is_active.is_(True), InboxStory.expires_at > datetime.utcnow()).order_by(InboxStory.created_at.desc()).limit(100).all()
    return [story for story in stories if _can_view_story(db, viewer, story)]


def create_story(db: Session, owner: User, media_url: str, media_type: str, caption: str | None, visibility: str | None) -> InboxStory:
    clean_type = (media_type or "image").strip().lower()
    clean_visibility = (visibility or "friends").strip().lower()
    clean_url = media_url.strip()
    if clean_type not in VALID_MEDIA_TYPES:
        raise ValueError("Story media type must be image or video")
    if clean_visibility not in VALID_VISIBILITY:
        raise ValueError("Invalid story visibility")
    try:
        asset = cdn_media_service.assert_user_owns_active_media_url(db, user=owner, public_url=clean_url, media_type=CdnMediaType.STORY_MEDIA)
    except ValueError as exc:
        raise ValueError("Upload story media before posting") from exc
    story = InboxStory(public_id=_public_id(), owner_user_id=owner.id, media_url=clean_url, media_type=clean_type, caption=(caption or '').strip() or None, visibility=clean_visibility)
    db.add(story)
    db.commit()
    db.refresh(story)
    asset.linked_entity_type = CdnMediaLinkedEntityType.STORY.value
    asset.linked_entity_id = str(story.id)
    db.add(asset)
    db.commit()
    db.refresh(story)
    return story


def mark_viewed(db: Session, viewer: User, public_id: str) -> InboxStory | None:
    story = db.query(InboxStory).filter(InboxStory.public_id == public_id).first()
    if story is None or not _can_view_story(db, viewer, story):
        return None
    existing = db.query(InboxStoryView).filter(InboxStoryView.story_id == story.id, InboxStoryView.viewer_user_id == viewer.id).first()
    if existing is None and story.owner_user_id != viewer.id:
        db.add(InboxStoryView(story_id=story.id, viewer_user_id=viewer.id))
        story.view_count += 1
        db.add(story)
        db.commit()
        db.refresh(story)
    return story


def delete_story(db: Session, owner: User, public_id: str) -> bool:
    story = db.query(InboxStory).filter(InboxStory.public_id == public_id, InboxStory.owner_user_id == owner.id).first()
    if story is None:
        return False
    story.is_active = False
    db.add(story)
    db.commit()
    return True
