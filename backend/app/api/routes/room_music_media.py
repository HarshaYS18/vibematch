import os
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from pydantic import BaseModel

from app.api.routes.users import get_current_user
from app.models.user import User

router = APIRouter(prefix="/media", tags=["Room Music Media"])

UPLOAD_ROOT = Path("static/uploads")
MAX_ROOM_MUSIC_BYTES = 25 * 1024 * 1024

ALLOWED_AUDIO_EXTENSIONS = {
    ".mp3",
    ".m4a",
    ".aac",
    ".wav",
    ".ogg",
    ".opus",
    ".webm",
    ".flac",
}

AUDIO_CONTENT_TYPES = {
    "audio/mpeg",
    "audio/mp3",
    "audio/mp4",
    "audio/aac",
    "audio/x-aac",
    "audio/wav",
    "audio/x-wav",
    "audio/ogg",
    "application/ogg",
    "audio/webm",
    "audio/flac",
    "audio/x-flac",
    "audio/m4a",
    "application/octet-stream",
}

EXTENSION_BY_CONTENT_TYPE = {
    "audio/mpeg": ".mp3",
    "audio/mp3": ".mp3",
    "audio/mp4": ".m4a",
    "audio/aac": ".aac",
    "audio/x-aac": ".aac",
    "audio/wav": ".wav",
    "audio/x-wav": ".wav",
    "audio/ogg": ".ogg",
    "application/ogg": ".ogg",
    "audio/webm": ".webm",
    "audio/flac": ".flac",
    "audio/x-flac": ".flac",
    "audio/m4a": ".m4a",
    "application/octet-stream": ".mp3",
}


class RoomMusicUploadResponse(BaseModel):
    url: str
    media_type: str
    content_type: str
    size_bytes: int
    filename: str


def _public_media_base_url(request: Request) -> str:
    configured = (
        os.getenv("PUBLIC_MEDIA_BASE_URL")
        or os.getenv("PUBLIC_BASE_URL")
        or os.getenv("MEDIA_BASE_URL")
        or ""
    ).strip()
    if configured:
        return configured.rstrip("/")
    return str(request.base_url).rstrip("/")


def _absolute_url(request: Request, path: str) -> str:
    return f"{_public_media_base_url(request)}{path}"


def _safe_upload_filename(filename: str, content_type: str) -> tuple[str, str]:
    original = Path(filename or "room_music.mp3")
    suffix = original.suffix.lower()

    if suffix not in ALLOWED_AUDIO_EXTENSIONS:
        suffix = EXTENSION_BY_CONTENT_TYPE.get(content_type, ".mp3")

    if suffix not in ALLOWED_AUDIO_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Unsupported room music file type")

    stem = original.stem.strip() or "room_music"
    safe_stem = "".join(
        ch if ch.isalnum() or ch in {"_", "-"} else "_" for ch in stem
    )[:80]

    return f"{uuid4().hex}_{safe_stem}{suffix}", suffix


@router.post("/room-music", response_model=RoomMusicUploadResponse)
async def upload_room_music(
    request: Request,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    content_type = (file.content_type or "application/octet-stream").lower().strip()

    if content_type not in AUDIO_CONTENT_TYPES and not content_type.startswith("audio/"):
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported audio content type: {content_type}",
        )

    filename, suffix = _safe_upload_filename(file.filename or "room_music.mp3", content_type)

    data = await file.read()
    size = len(data)
    if size <= 0:
        raise HTTPException(status_code=400, detail="Uploaded audio is empty")
    if size > MAX_ROOM_MUSIC_BYTES:
        raise HTTPException(
            status_code=413,
            detail="Audio file is too large. Max allowed is 25 MB",
        )

    target_dir = UPLOAD_ROOT / "room_music" / f"user_{current_user.id}"
    target_dir.mkdir(parents=True, exist_ok=True)

    target_path = target_dir / filename
    target_path.write_bytes(data)

    public_path = f"/static/uploads/room_music/user_{current_user.id}/{filename}"
    return RoomMusicUploadResponse(
        url=_absolute_url(request, public_path),
        media_type="audio",
        content_type=content_type if content_type != "application/octet-stream" else "audio/mpeg",
        size_bytes=size,
        filename=filename,
    )
