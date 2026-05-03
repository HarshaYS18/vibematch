from __future__ import annotations

import os
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from app.api.routes.users import get_current_user
from app.models.user import User


router = APIRouter(prefix="/uploads", tags=["Uploads"])

UPLOAD_ROOT = Path("uploads")
ROOM_COVER_DIR = UPLOAD_ROOT / "room_covers"
MAX_ROOM_COVER_BYTES = 5 * 1024 * 1024
ALLOWED_ROOM_COVER_CONTENT_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}


@router.post("/room-cover")
async def upload_room_cover(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    if file.content_type not in ALLOWED_ROOM_COVER_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Room cover must be JPG, PNG, or WEBP.",
        )

    content = await file.read()
    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty.",
        )

    if len(content) > MAX_ROOM_COVER_BYTES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Room cover must be 5MB or smaller.",
        )

    ROOM_COVER_DIR.mkdir(parents=True, exist_ok=True)
    extension = ALLOWED_ROOM_COVER_CONTENT_TYPES[file.content_type]
    filename = f"room-cover-{current_user.id}-{uuid.uuid4().hex}{extension}"
    file_path = ROOM_COVER_DIR / filename

    with open(file_path, "wb") as output:
        output.write(content)

    normalized_path = file_path.as_posix()
    if not normalized_path.startswith("/"):
        normalized_path = f"/{normalized_path}"

    return {
        "ok": True,
        "url": normalized_path,
        "content_type": file.content_type,
        "size_bytes": len(content),
    }
