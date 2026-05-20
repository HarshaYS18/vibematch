from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.inbox import InboxStoryCreateRequest, InboxStoryListResponse, InboxStoryResponse
from app.services import inbox_story_service

router = APIRouter(tags=["Inbox Stories"])


@router.get("/stories", response_model=InboxStoryListResponse)
def list_inbox_stories(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    stories = inbox_story_service.list_visible_stories(db, current_user)
    return InboxStoryListResponse(stories=[InboxStoryResponse(**inbox_story_service.story_to_dict(db, story, current_user)) for story in stories])


@router.post("/stories", response_model=InboxStoryResponse)
def create_inbox_story(request: InboxStoryCreateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    try:
        story = inbox_story_service.create_story(
            db=db,
            owner=current_user,
            media_url=request.media_url,
            media_type=request.media_type,
            caption=request.caption,
            visibility=request.visibility,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return InboxStoryResponse(**inbox_story_service.story_to_dict(db, story, current_user))


@router.post("/stories/{story_id}/view", response_model=InboxStoryResponse)
def mark_story_viewed(story_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    story = inbox_story_service.mark_viewed(db, current_user, story_id)
    if story is None:
        raise HTTPException(status_code=404, detail="Story not found")
    return InboxStoryResponse(**inbox_story_service.story_to_dict(db, story, current_user))


@router.delete("/stories/{story_id}")
def delete_inbox_story(story_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    deleted = inbox_story_service.delete_story(db, current_user, story_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Story not found")
    return {"status": "deleted"}
