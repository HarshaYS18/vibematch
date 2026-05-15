import re
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from pydantic import BaseModel

from app.api.routes.users import get_current_user
from app.models.user import User

router = APIRouter(prefix="/media", tags=["Media"])

UPLOAD_ROOT = Path("static/uploads")
MAX_AVATAR_BYTES = 10 * 1024 * 1024
MAX_PROFILE_COVER_BYTES = 10 * 1024 * 1024
MAX_ROOM_AVATAR_BYTES = 10 * 1024 * 1024
MAX_CHAT_IMAGE_BYTES = 10 * 1024 * 1024
MAX_HOME_BANNER_BYTES = 10 * 1024 * 1024
MAX_VIBE_MEDIA_BYTES = 20 * 1024 * 1024
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
ALLOWED_VIDEO_TYPES = {"video/mp4", "video/webm", "video/quicktime"}
GENERIC_MULTIPART_TYPES = {"", "application/octet-stream", "text/plain"}


class MediaUploadResponse(BaseModel):
    url: str
    media_type: str
    content_type: str
    size_bytes: int


def _content_type_from_filename(filename: str) -> str | None:
    suffix = Path(filename or "").suffix.lower()
    return {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
        ".gif": "image/gif",
        ".mp4": "video/mp4",
        ".webm": "video/webm",
        ".mov": "video/quicktime",
    }.get(suffix)


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
    return {
        "image/jpeg": ".jpg",
        "image/png": ".png",
        "image/webp": ".webp",
        "image/gif": ".gif",
        "video/mp4": ".mp4",
        "video/webm": ".webm",
        "video/quicktime": ".mov",
    }.get(content_type, ".bin")


def _absolute_url(request: Request, path: str) -> str:
    base = str(request.base_url).rstrip("/")
    return f"{base}{path}"


async def _save_upload(file: UploadFile, *, folder: str, max_size: int, allowed_types: set[str], request: Request) -> MediaUploadResponse:
    content_type = _resolve_content_type(file)
    if content_type not in allowed_types:
        raise HTTPException(status_code=400, detail=f"Unsupported file type: {content_type or 'unknown'}")

    data = await file.read()
    size = len(data)
    if size <= 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty")
    if size > max_size:
        raise HTTPException(status_code=413, detail=f"File is too large. Max allowed is {max_size // (1024 * 1024)} MB")

    target_dir = UPLOAD_ROOT / folder
    target_dir.mkdir(parents=True, exist_ok=True)
    filename = f"{uuid4().hex}{_safe_extension(file.filename or '', content_type)}"
    target_path = target_dir / filename
    target_path.write_bytes(data)

    public_path = f"/static/uploads/{folder}/{filename}"
    return MediaUploadResponse(
        url=_absolute_url(request, public_path),
        media_type="video" if content_type.startswith("video/") else "image",
        content_type=content_type,
        size_bytes=size,
    )


@router.post("/avatar", response_model=MediaUploadResponse)
async def upload_avatar(request: Request, file: UploadFile = File(...), current_user: User = Depends(get_current_user)):
    return await _save_upload(file, folder=f"avatars/user_{current_user.id}", max_size=MAX_AVATAR_BYTES, allowed_types=ALLOWED_IMAGE_TYPES, request=request)


@router.post("/profile-cover", response_model=MediaUploadResponse)
async def upload_profile_cover(request: Request, file: UploadFile = File(...), current_user: User = Depends(get_current_user)):
    return await _save_upload(file, folder=f"profile_covers/user_{current_user.id}", max_size=MAX_PROFILE_COVER_BYTES, allowed_types=ALLOWED_IMAGE_TYPES, request=request)


@router.post("/room-avatar", response_model=MediaUploadResponse)
async def upload_room_avatar(request: Request, file: UploadFile = File(...), current_user: User = Depends(get_current_user)):
    return await _save_upload(file, folder=f"room_avatars/user_{current_user.id}", max_size=MAX_ROOM_AVATAR_BYTES, allowed_types=ALLOWED_IMAGE_TYPES, request=request)


@router.post("/home-banner", response_model=MediaUploadResponse)
async def upload_home_banner(request: Request, file: UploadFile = File(...), current_user: User = Depends(get_current_user)):
    return await _save_upload(file, folder=f"home_banners/user_{current_user.id}", max_size=MAX_HOME_BANNER_BYTES, allowed_types=ALLOWED_IMAGE_TYPES, request=request)


@router.post("/chat-image", response_model=MediaUploadResponse)
async def upload_chat_image(request: Request, file: UploadFile = File(...), current_user: User = Depends(get_current_user)):
    return await _save_upload(file, folder=f"chat_images/user_{current_user.id}", max_size=MAX_CHAT_IMAGE_BYTES, allowed_types=ALLOWED_IMAGE_TYPES, request=request)


@router.post("/vibes", response_model=MediaUploadResponse)
async def upload_vibe_media(request: Request, file: UploadFile = File(...), current_user: User = Depends(get_current_user)):
    return await _save_upload(file, folder=f"vibes/user_{current_user.id}", max_size=MAX_VIBE_MEDIA_BYTES, allowed_types=ALLOWED_IMAGE_TYPES | ALLOWED_VIDEO_TYPES, request=request)
