from datetime import datetime, timedelta

from sqlalchemy import and_, exists
from sqlalchemy.orm import Session

from app.models.follow import UserFollow
from app.models.user import User


_ONLINE_WINDOW = timedelta(minutes=5)


def is_user_online(user: User) -> bool:
    last_seen = user.last_seen_at or user.last_login_at
    if last_seen is None:
        return False
    return last_seen >= datetime.utcnow() - _ONLINE_WINDOW


def public_user_summary(
    user: User,
    *,
    current_user: User | None = None,
    is_following_value: bool | None = None,
    is_followed_by_value: bool | None = None,
) -> dict:
    following = False
    followed_by = False
    if current_user is not None and current_user.id != user.id:
        following = is_following_value if is_following_value is not None else False
        followed_by = is_followed_by_value if is_followed_by_value is not None else False
    return {
        "id": user.id,
        "public_user_id": user.public_user_id,
        "username": user.username,
        "display_name": user.display_name,
        "avatar_url": user.avatar_url,
        "is_online": is_user_online(user),
        "last_seen_at": user.last_seen_at,
        "is_following": following,
        "is_followed_by": followed_by,
        "follows_me": followed_by,
        "is_friend": following and followed_by,
    }


def get_user_by_id(db: Session, user_id: int) -> User | None:
    return db.query(User).filter(User.id == user_id, User.is_active.is_(True)).first()


def is_following(db: Session, follower_user_id: int, followed_user_id: int) -> bool:
    return db.query(
        exists().where(
            and_(
                UserFollow.follower_user_id == follower_user_id,
                UserFollow.followed_user_id == followed_user_id,
            )
        )
    ).scalar()


def follow_status(db: Session, current_user: User, target_user: User) -> dict:
    following = is_following(db, current_user.id, target_user.id)
    followed_by = is_following(db, target_user.id, current_user.id)
    friends = following and followed_by
    if friends:
        action_label = "Friends"
    elif followed_by and not following:
        action_label = "Follow Back"
    elif following:
        action_label = "Following"
    else:
        action_label = "Follow"
    return {
        "target_user": public_user_summary(
            target_user,
            current_user=current_user,
            is_following_value=following,
            is_followed_by_value=followed_by,
        ),
        "is_following": following,
        "is_followed_by": followed_by,
        "is_friends": friends,
        "action_label": action_label,
    }


def follow_user(db: Session, current_user: User, target_user: User) -> dict:
    existing = db.query(UserFollow).filter(
        UserFollow.follower_user_id == current_user.id,
        UserFollow.followed_user_id == target_user.id,
    ).first()
    if existing:
        status = follow_status(db, current_user, target_user)
        return {**status, "status": "already_following", "created_at": existing.created_at}

    item = UserFollow(follower_user_id=current_user.id, followed_user_id=target_user.id)
    db.add(item)
    db.commit()
    db.refresh(item)
    status = follow_status(db, current_user, target_user)
    return {**status, "status": "followed", "created_at": item.created_at}


def unfollow_user(db: Session, current_user: User, target_user: User) -> dict:
    existing = db.query(UserFollow).filter(
        UserFollow.follower_user_id == current_user.id,
        UserFollow.followed_user_id == target_user.id,
    ).first()
    if existing:
        db.delete(existing)
        db.commit()
    status = follow_status(db, current_user, target_user)
    return {**status, "status": "unfollowed", "created_at": None}


def list_following(db: Session, current_user: User) -> list[User]:
    return (
        db.query(User)
        .join(UserFollow, UserFollow.followed_user_id == User.id)
        .filter(UserFollow.follower_user_id == current_user.id, User.is_active.is_(True))
        .order_by(UserFollow.created_at.desc())
        .all()
    )


def list_followers(db: Session, current_user: User) -> list[User]:
    return (
        db.query(User)
        .join(UserFollow, UserFollow.follower_user_id == User.id)
        .filter(UserFollow.followed_user_id == current_user.id, User.is_active.is_(True))
        .order_by(UserFollow.created_at.desc())
        .all()
    )


def list_friends(db: Session, current_user: User) -> list[User]:
    following_ids = db.query(UserFollow.followed_user_id).filter(UserFollow.follower_user_id == current_user.id).subquery()
    return (
        db.query(User)
        .join(UserFollow, UserFollow.follower_user_id == User.id)
        .filter(
            UserFollow.followed_user_id == current_user.id,
            User.id.in_(following_ids),
            User.is_active.is_(True),
        )
        .order_by(UserFollow.created_at.desc())
        .all()
    )
