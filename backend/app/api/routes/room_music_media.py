from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from pydantic import BaseModel

from app.api.routes.users import get_current_user
from app.models.user import User

router = APIRouter(prefix="/media", tags=["Room Music Media"])

UPLOAD_ROOT = Path("static/uploads")
MAX_ROOM_MUSIC_BYTES = 25 * 1024 * 1024
ALLOWED_AUDIO_EXTENSIONS = {".mp3", ".m4a", ".aac", ".wav", ".ogg", ".opus", ".webm", ".flac"}
AUDIO_CONTENT_TYPES_BY_EXTENSION = {
    ".mp3": "audio/mpeg",
    ".m4a": "audio/mp4",
    ".aac": "audio/aac",
    ".wav": "audio/wav",
    ".ogg": "audio/ogg",
    ".opus": "audio/ogg",
    ".webm": "audio/webm",
    ".flac": "audio/flac",
}


class RoomMusicUploadResponse(BaseModel):
    url: str
    media_type: str
    content_type: str
    size_bytes: int
    filename: str


def _absolute_url(request: Request, path: str) -> str:
    base = str(request.base_url).rstrip("/")
    return f"{base}{path}"


def _safe_filename(filename: str) -> tuple[str, str]:
    original = Path(filename or "room_music.mp3")
    suffix = original.suffix.lower()
    if suffix not in ALLOWED_AUDIO_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Unsupported audio file type")
    stem = original.stem.strip() or "room_music"
    safe_stem = "".join(ch if ch.isalnum() or ch in {"_", "-"} else "_" for ch in stem)[:80]
    return f"{uuid4().hex}_{safe_stem}{suffix}", AUDIO_CONTENT_TYPES_BY_EXTENSION[suffix]


@router.post("/room-music", response_model=RoomMusicUploadResponse)
async def upload_room_music(
    request: Request,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    filename, content_type = _safe_filename(file.filename or "room_music.mp3")
    data = await file.read()
    size = len(data)
    if size <= 0:
        raise HTTPException(status_code=400, detail="Uploaded audio is empty")
    if size > MAX_ROOM_MUSIC_BYTES:
        raise HTTPException(status_code=413, detail="Audio file is too large. Max allowed is 25 MB")

    target_dir = UPLOAD_ROOT / "room_music" / f"user_{current_user.id}"
    target_dir.mkdir(parents=True, exist_ok=True)
    target_path = target_dir / filename
    target_path.write_bytes(data)

    public_path = f"/static/uploads/room_music/user_{current_user.id}/{filename}"
    return RoomMusicUploadResponse(
        url=_absolute_url(request, public_path),
        media_type="audio",
        content_type=content_type,
        size_bytes=size,
        filename=filename,
    )
