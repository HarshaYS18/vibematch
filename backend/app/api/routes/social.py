from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.social import (
    FollowActionResponse,
    FollowStatusResponse,
    FollowersListResponse,
    FollowingListResponse,
    FriendsListResponse,
    PublicUserSummary,
)
from app.services import social_service

router = APIRouter(prefix="/social", tags=["Social"])


def _get_target_user(db: Session, target_user_id: int, current_user: User) -> User:
    if target_user_id == current_user.id:
        raise HTTPException(status_code=400, detail="You cannot use this action on yourself.")
    target_user = social_service.get_user_by_id(db, target_user_id)
    if not target_user:
        raise HTTPException(status_code=404, detail="Target user not found.")
    return target_user


def _get_target_user_by_public_id(db: Session, public_user_id: int, current_user: User) -> User:
    if public_user_id == current_user.public_user_id:
        raise HTTPException(status_code=400, detail="You cannot use this action on yourself.")
    target_user = db.query(User).filter(User.public_user_id == public_user_id, User.is_active.is_(True)).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="Target user not found.")
    return target_user


@router.get("/users/{target_user_id}/follow-status", response_model=FollowStatusResponse)
def get_follow_status(
    target_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_user = _get_target_user(db, target_user_id, current_user)
    return FollowStatusResponse(**social_service.follow_status(db, current_user, target_user))


@router.post("/users/{target_user_id}/follow", response_model=FollowActionResponse)
def follow_user(
    target_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_user = _get_target_user(db, target_user_id, current_user)
    return FollowActionResponse(**social_service.follow_user(db, current_user, target_user))


@router.delete("/users/{target_user_id}/follow", response_model=FollowActionResponse)
def unfollow_user(
    target_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_user = _get_target_user(db, target_user_id, current_user)
    return FollowActionResponse(**social_service.unfollow_user(db, current_user, target_user))


@router.get("/public-users/{public_user_id}/follow-status", response_model=FollowStatusResponse)
def get_follow_status_by_public_id(
    public_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_user = _get_target_user_by_public_id(db, public_user_id, current_user)
    return FollowStatusResponse(**social_service.follow_status(db, current_user, target_user))


@router.post("/public-users/{public_user_id}/follow", response_model=FollowActionResponse)
def follow_user_by_public_id(
    public_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_user = _get_target_user_by_public_id(db, public_user_id, current_user)
    return FollowActionResponse(**social_service.follow_user(db, current_user, target_user))


@router.delete("/public-users/{public_user_id}/follow", response_model=FollowActionResponse)
def unfollow_user_by_public_id(
    public_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_user = _get_target_user_by_public_id(db, public_user_id, current_user)
    return FollowActionResponse(**social_service.unfollow_user(db, current_user, target_user))


@router.get("/following", response_model=FollowingListResponse)
def list_following(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    users = social_service.list_following(db, current_user)
    return FollowingListResponse(users=[PublicUserSummary(**social_service.public_user_summary(user)) for user in users])


@router.get("/followers", response_model=FollowersListResponse)
def list_followers(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    users = social_service.list_followers(db, current_user)
    return FollowersListResponse(users=[PublicUserSummary(**social_service.public_user_summary(user)) for user in users])


@router.get("/friends", response_model=FriendsListResponse)
def list_friends(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    users = social_service.list_friends(db, current_user)
    return FriendsListResponse(users=[PublicUserSummary(**social_service.public_user_summary(user)) for user in users])
