import re
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.cdn_media import CdnMediaLinkedEntityType, CdnMediaType
from app.models.user import User
from app.services import cdn_media_service, media_moderation_service, media_storage_service
from app.services.media_storage_service import MediaStorageError

router = APIRouter(prefix="/media", tags=["Media"])

MAX_AVATAR_BYTES = 10 * 1024 * 1024
MAX_PROFILE_COVER_BYTES = 10 * 1024 * 1024
MAX_ROOM_AVATAR_BYTES = 10 * 1024 * 1024
MAX_ROOM_COVER_BYTES = 10 * 1024 * 1024
MAX_ROOM_BACKGROUND_BYTES = 15 * 1024 * 1024
MAX_CHAT_IMAGE_BYTES = 10 * 1024 * 1024
MAX_CHAT_DOCUMENT_BYTES = 20 * 1024 * 1024
MAX_CHAT_VOICE_BYTES = 10 * 1024 * 1024
MAX_HOME_BANNER_BYTES = 10 * 1024 * 1024
MAX_VIBE_MEDIA_BYTES = 20 * 1024 * 1024
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
ALLOWED_VIDEO_TYPES = {"video/mp4", "video/webm", "video/quicktime"}
ALLOWED_AUDIO_TYPES = {"audio/mpeg", "audio/mp3", "audio/mp4", "audio/aac", "audio/wav", "audio/x-wav", "audio/webm", "audio/ogg", "audio/m4a"}
ALLOWED_DOCUMENT_TYPES = {"application/pdf", "text/plain", "text/csv", "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "application/vnd.ms-excel", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "application/vnd.ms-powerpoint", "application/vnd.openxmlformats-officedocument.presentationml.presentation", "application/zip"}
GENERIC_MULTIPART_TYPES = {"", "application/octet-stream", "text/plain"}


class MediaUploadResponse(BaseModel):
    url: str
    media_type: str
    content_type: str
    size_bytes: int
    media_id: str | None = None
    upload_status: str | None = None
    moderation_status: str | None = None
    expires_at: str | None = None


def _content_type_from_filename(filename: str) -> str | None:
    suffix = Path(filename or "").suffix.lower()
    return {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp", ".gif": "image/gif", ".mp4": "video/mp4", ".webm": "video/webm", ".mov": "video/quicktime", ".mp3": "audio/mpeg", ".m4a": "audio/mp4", ".aac": "audio/aac", ".wav": "audio/wav", ".ogg": "audio/ogg", ".oga": "audio/ogg", ".opus": "audio/ogg", ".weba": "audio/webm", ".pdf": "application/pdf", ".txt": "text/plain", ".csv": "text/csv", ".doc": "application/msword", ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document", ".xls": "application/vnd.ms-excel", ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", ".ppt": "application/vnd.ms-powerpoint", ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation", ".zip": "application/zip"}.get(suffix)


def _resolve_content_type(file: UploadFile) -> str:
    raw = (file.content_type or "").lower().strip()
    inferred = _content_type_from_filename(file.filename or "")
    if raw in GENERIC_MULTIPART_TYPES and inferred:
        return inferred
    return raw


def _safe_extension(filename: str, content_type: str) -> str:
    suffix = Path(filename or "").suffix.lower()
    if re.fullmatch(r"\.[a-z0-9]{1,8}", suffix):
        return suffix
    return {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp", "image/gif": ".gif", "video/mp4": ".mp4", "video/webm": ".webm", "video/quicktime": ".mov", "audio/mpeg": ".mp3", "audio/mp3": ".mp3", "audio/mp4": ".m4a", "audio/aac": ".aac", "audio/wav": ".wav", "audio/x-wav": ".wav", "audio/webm": ".weba", "audio/ogg": ".ogg", "audio/m4a": ".m4a", "application/pdf": ".pdf", "text/plain": ".txt", "text/csv": ".csv", "application/msword": ".doc", "application/vnd.openxmlformats-officedocument.wordprocessingml.document": ".docx", "application/vnd.ms-excel": ".xls", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": ".xlsx", "application/vnd.ms-powerpoint": ".ppt", "application/vnd.openxmlformats-officedocument.presentationml.presentation": ".pptx", "application/zip": ".zip"}.get(content_type, ".bin")


def _media_kind_from_content_type(content_type: str) -> str:
    if content_type.startswith("video/"):
        return "video"
    if content_type.startswith("image/"):
        return "image"
    if content_type.startswith("audio/"):
        return "audio"
    return "document"


async def _save_upload(file: UploadFile, *, folder: str, max_size: int, allowed_types: set[str], request: Request) -> tuple[MediaUploadResponse, str]:
    content_type = _resolve_content_type(file)
    if content_type not in allowed_types:
        raise HTTPException(status_code=400, detail=f"Unsupported file type: {content_type or 'unknown'}")
    data = await file.read(max_size + 1)
    size = len(data)
    if size <= 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty")
    if size > max_size:
        raise HTTPException(status_code=413, detail=f"File is too large. Max allowed is {max_size // (1024 * 1024)} MB")
    filename = f"{uuid4().hex}{_safe_extension(file.filename or '', content_type)}"
    object_key = f"{folder}/{filename}"
    try:
        stored = media_storage_service.store_media_bytes(data=data, object_key=object_key, content_type=content_type, request_base_url=str(request.base_url))
    except MediaStorageError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return (MediaUploadResponse(url=stored.public_url, media_type=_media_kind_from_content_type(content_type), content_type=content_type, size_bytes=size), stored.object_key)


def _with_asset(result: MediaUploadResponse, asset) -> MediaUploadResponse:
    result.media_id = asset.public_id
    result.upload_status = asset.upload_status
    result.moderation_status = asset.moderation_status
    result.expires_at = asset.expires_at.isoformat() if asset.expires_at else None
    return result


def _audit_if_supported_image(db: Session, asset, *, content_type: str, actor_user_id: int) -> None:
    if content_type.startswith("image/"):
        media_moderation_service.audit_image_media(db, asset=asset, actor_user_id=actor_user_id)


@router.post("/avatar", response_model=MediaUploadResponse)
async def upload_avatar(request: Request, file: UploadFile = File(...), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    result, object_key = await _save_upload(file, folder=f"avatars/user_{current_user.id}", max_size=MAX_AVATAR_BYTES, allowed_types=ALLOWED_IMAGE_TYPES, request=request)
    asset = cdn_media_service.register_uploaded_media(db, owner=current_user, media_type=CdnMediaType.PROFILE_PICTURE, public_url=result.url, object_key=object_key, mime_type=result.content_type, size_bytes=result.size_bytes, linked_entity_type=CdnMediaLinkedEntityType.USER_PROFILE, linked_entity_id=str(current_user.id))
    _audit_if_supported_image(db, asset, content_type=result.content_type, actor_user_id=current_user.id)
    cdn_media_service.mark_profile_picture_replaced(db, user=current_user, new_asset=asset, actor_user_id=current_user.id)
    db.refresh(asset)
    return _with_asset(result, asset)


@router.post("/profile-cover", response_model=MediaUploadResponse)
async def upload_profile_cover(request: Request, file: UploadFile = File(...), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    result, object_key = await _save_upload(file, folder=f"profile_covers/user_{current_user.id}", max_size=MAX_PROFILE_COVER_BYTES, allowed_types=ALLOWED_IMAGE_TYPES, request=request)
    asset = cdn_media_service.register_uploaded_media(db, owner=current_user, media_type=CdnMediaType.COVER_PHOTO, public_url=result.url, object_key=object_key, mime_type=result.content_type, size_bytes=result.size_bytes, linked_entity_type=CdnMediaLinkedEntityType.USER_PROFILE, linked_entity_id=str(current_user.id))
    _audit_if_supported_image(db, asset, content_type=result.content_type, actor_user_id=current_user.id)
    cdn_media_service.add_cover_photo_reference(db, user=current_user, new_asset=asset, actor_user_id=current_user.id)
    db.refresh(asset)
    return _with_asset(result, asset)


@router.post("/room-avatar", response_model=MediaUploadResponse)
async def upload_room_avatar(request: Request, file: UploadFile = File(...), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    result, object_key = await _save_upload(file, folder=f"room_avatars/user_{current_user.id}", max_size=MAX_ROOM_AVATAR_BYTES, allowed_types=ALLOWED_IMAGE_TYPES, request=request)
    asset = cdn_media_service.register_uploaded_media(db, owner=current_user, media_type=CdnMediaType.ROOM_AVATAR, public_url=result.url, object_key=object_key, mime_type=result.content_type, size_bytes=result.size_bytes, linked_entity_type=CdnMediaLinkedEntityType.ROOM)
    return _with_asset(result, asset)


@router.post("/room-cover", response_model=MediaUploadResponse)
async def upload_room_cover(request: Request, file: UploadFile = File(...), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    result, object_key = await _save_upload(file, folder=f"room_covers/user_{current_user.id}", max_size=MAX_ROOM_COVER_BYTES, allowed_types=ALLOWED_IMAGE_TYPES, request=request)
    asset = cdn_media_service.register_uploaded_media(db, owner=current_user, media_type=CdnMediaType.ROOM_COVER, public_url=result.url, object_key=object_key, mime_type=result.content_type, size_bytes=result.size_bytes, linked_entity_type=CdnMediaLinkedEntityType.ROOM)
    return _with_asset(result, asset)


@router.post("/room-background", response_model=MediaUploadResponse)
async def upload_room_background(request: Request, file: UploadFile = File(...), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    result, object_key = await _save_upload(file, folder=f"room_backgrounds/user_{current_user.id}", max_size=MAX_ROOM_BACKGROUND_BYTES, allowed_types=ALLOWED_IMAGE_TYPES, request=request)
    asset = cdn_media_service.register_uploaded_media(db, owner=current_user, media_type=CdnMediaType.ROOM_BACKGROUND, public_url=result.url, object_key=object_key, mime_type=result.content_type, size_bytes=result.size_bytes, linked_entity_type=CdnMediaLinkedEntityType.ROOM)
    return _with_asset(result, asset)


@router.post("/home-banner", response_model=MediaUploadResponse)
async def upload_home_banner(request: Request, file: UploadFile = File(...), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    result, object_key = await _save_upload(file, folder=f"home_banners/user_{current_user.id}", max_size=MAX_HOME_BANNER_BYTES, allowed_types=ALLOWED_IMAGE_TYPES, request=request)
    asset = cdn_media_service.register_uploaded_media(db, owner=current_user, media_type=CdnMediaType.HOME_BANNER, public_url=result.url, object_key=object_key, mime_type=result.content_type, size_bytes=result.size_bytes, linked_entity_type=CdnMediaLinkedEntityType.HOME_BANNER)
    return _with_asset(result, asset)


@router.post("/chat-image", response_model=MediaUploadResponse)
async def upload_chat_image(request: Request, file: UploadFile = File(...), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    result, object_key = await _save_upload(file, folder=f"chat_images/user_{current_user.id}", max_size=MAX_CHAT_IMAGE_BYTES, allowed_types=ALLOWED_IMAGE_TYPES, request=request)
    asset = cdn_media_service.register_uploaded_media(db, owner=current_user, media_type=CdnMediaType.INBOX_MEDIA, public_url=result.url, object_key=object_key, mime_type=result.content_type, size_bytes=result.size_bytes, linked_entity_type=CdnMediaLinkedEntityType.INBOX_MESSAGE)
    return _with_asset(result, asset)


@router.post("/chat-document", response_model=MediaUploadResponse)
async def upload_chat_document(request: Request, file: UploadFile = File(...), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    result, object_key = await _save_upload(file, folder=f"chat_documents/user_{current_user.id}", max_size=MAX_CHAT_DOCUMENT_BYTES, allowed_types=ALLOWED_DOCUMENT_TYPES, request=request)
    asset = cdn_media_service.register_uploaded_media(db, owner=current_user, media_type=CdnMediaType.INBOX_MEDIA, public_url=result.url, object_key=object_key, mime_type=result.content_type, size_bytes=result.size_bytes, linked_entity_type=CdnMediaLinkedEntityType.INBOX_MESSAGE)
    return _with_asset(result, asset)


@router.post("/chat-voice", response_model=MediaUploadResponse)
async def upload_chat_voice(request: Request, file: UploadFile = File(...), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    result, object_key = await _save_upload(file, folder=f"chat_voice/user_{current_user.id}", max_size=MAX_CHAT_VOICE_BYTES, allowed_types=ALLOWED_AUDIO_TYPES, request=request)
    asset = cdn_media_service.register_uploaded_media(db, owner=current_user, media_type=CdnMediaType.INBOX_MEDIA, public_url=result.url, object_key=object_key, mime_type=result.content_type, size_bytes=result.size_bytes, linked_entity_type=CdnMediaLinkedEntityType.INBOX_MESSAGE)
    return _with_asset(result, asset)


@router.post("/vibes", response_model=MediaUploadResponse)
async def upload_vibe_media(request: Request, file: UploadFile = File(...), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    result, object_key = await _save_upload(file, folder=f"vibes/user_{current_user.id}", max_size=MAX_VIBE_MEDIA_BYTES, allowed_types=ALLOWED_IMAGE_TYPES | ALLOWED_VIDEO_TYPES, request=request)
    asset = cdn_media_service.register_uploaded_media(db, owner=current_user, media_type=CdnMediaType.VIBES_MEDIA, public_url=result.url, object_key=object_key, mime_type=result.content_type, size_bytes=result.size_bytes, linked_entity_type=CdnMediaLinkedEntityType.VIBES_POST)
    _audit_if_supported_image(db, asset, content_type=result.content_type, actor_user_id=current_user.id)
    return _with_asset(result, asset)


@router.post("/story", response_model=MediaUploadResponse)
async def upload_story_media(request: Request, file: UploadFile = File(...), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    result, object_key = await _save_upload(file, folder=f"stories/user_{current_user.id}", max_size=MAX_VIBE_MEDIA_BYTES, allowed_types=ALLOWED_IMAGE_TYPES | ALLOWED_VIDEO_TYPES, request=request)
    asset = cdn_media_service.register_uploaded_media(db, owner=current_user, media_type=CdnMediaType.STORY_MEDIA, public_url=result.url, object_key=object_key, mime_type=result.content_type, size_bytes=result.size_bytes, linked_entity_type=CdnMediaLinkedEntityType.STORY)
    _audit_if_supported_image(db, asset, content_type=result.content_type, actor_user_id=current_user.id)
    return _with_asset(result, asset)
