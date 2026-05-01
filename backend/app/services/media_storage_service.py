from __future__ import annotations

import re
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

from fastapi import HTTPException, UploadFile, status

from app.core.config import settings
from app.core.upload_limits import (
    MAX_AVATAR_UPLOAD_BYTES,
    MAX_MOMENT_UPLOAD_BYTES,
)


@dataclass(frozen=True)
class StoredMediaFile:
    storage_backend: str
    storage_key: str
    public_url: str
    filename: str
    content_type: str
    size_bytes: int
    bucket: str


class MediaBucket:
    AVATARS = "avatars"
    ROOM_IMAGES = "room-images"
    ROOM_BACKGROUNDS = "room-backgrounds"
    CHAT_IMAGES = "chat-images"
    VIBE_MEDIA = "vibe-media"
    GIFTS = "gifts"
    TEST = "test"


class LocalMediaStorageService:
    """Local laptop CDN-style storage.

    The important production-safe idea is that features should store the
    `storage_key`, not only the absolute URL. Today that key is served from the
    laptop under `/media/...`; later the same key can point to Cloudflare R2,
    S3, or another CDN by changing the storage adapter/base URL.
    """

    allowed_image_extensions = {
        ".jpg",
        ".jpeg",
        ".png",
        ".webp",
        ".gif",
        ".heic",
        ".heif",
        ".apng",
    }

    allowed_video_extensions = {
        ".mp4",
        ".webm",
        ".mov",
    }

    image_content_type_prefixes = ("image/",)
    video_content_type_prefixes = ("video/",)

    def __init__(self, root_dir: str | None = None) -> None:
        self.root_dir = Path(root_dir or settings.MEDIA_ROOT_DIR).resolve()
        self.root_dir.mkdir(parents=True, exist_ok=True)

    async def save_upload(
        self,
        *,
        file: UploadFile,
        bucket: str,
        allowed_extensions: Iterable[str],
        allowed_content_type_prefixes: Iterable[str],
        max_size_bytes: int,
    ) -> StoredMediaFile:
        original_filename = file.filename or "upload"
        extension = self._safe_extension(original_filename)
        allowed_extension_set = {item.lower() for item in allowed_extensions}

        if extension not in allowed_extension_set:
            raise HTTPException(
                status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                detail=f"Unsupported file type '{extension or 'unknown'}'.",
            )

        content_type = (file.content_type or "application/octet-stream").lower()
        if not any(
            content_type.startswith(prefix.lower())
            for prefix in allowed_content_type_prefixes
        ):
            raise HTTPException(
                status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                detail=f"Unsupported content type '{content_type}'.",
            )

        now = datetime.now(timezone.utc)
        safe_bucket = self._safe_path_segment(bucket)
        unique_name = f"{uuid.uuid4().hex}{extension}"
        storage_key = f"{safe_bucket}/{now:%Y/%m/%d}/{unique_name}"
        destination = self.root_dir / storage_key
        destination.parent.mkdir(parents=True, exist_ok=True)

        size_bytes = 0
        try:
            with destination.open("wb") as output:
                while True:
                    chunk = await file.read(1024 * 1024)
                    if not chunk:
                        break

                    size_bytes += len(chunk)
                    if size_bytes > max_size_bytes:
                        output.close()
                        destination.unlink(missing_ok=True)
                        max_mb = round(max_size_bytes / (1024 * 1024), 2)
                        raise HTTPException(
                            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                            detail=f"File is too large. Maximum allowed size is {max_mb} MB.",
                        )

                    output.write(chunk)
        finally:
            await file.close()

        public_url = self.public_url_for_key(storage_key)
        return StoredMediaFile(
            storage_backend=settings.MEDIA_STORAGE_BACKEND,
            storage_key=storage_key,
            public_url=public_url,
            filename=original_filename,
            content_type=content_type,
            size_bytes=size_bytes,
            bucket=safe_bucket,
        )

    def public_url_for_key(self, storage_key: str) -> str:
        clean_key = storage_key.lstrip("/").replace("\\", "/")
        public_path = settings.MEDIA_PUBLIC_PATH.rstrip("/")
        relative_url = f"{public_path}/{clean_key}"

        base_url = settings.MEDIA_PUBLIC_BASE_URL.strip().rstrip("/")
        if not base_url:
            return relative_url

        return f"{base_url}{relative_url}"

    def _safe_extension(self, filename: str) -> str:
        suffix = Path(filename).suffix.lower().strip()
        if not suffix:
            return ""
        return suffix

    def _safe_path_segment(self, value: str) -> str:
        normalized = value.strip().lower().replace("_", "-")
        normalized = re.sub(r"[^a-z0-9-]+", "-", normalized)
        normalized = re.sub(r"-+", "-", normalized).strip("-")
        if not normalized:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid media bucket.",
            )
        return normalized


media_storage_service = LocalMediaStorageService()


def max_size_for_bucket(bucket: str) -> int:
    normalized = bucket.strip().lower()
    if normalized in {
        MediaBucket.AVATARS,
        MediaBucket.ROOM_IMAGES,
        MediaBucket.ROOM_BACKGROUNDS,
        MediaBucket.CHAT_IMAGES,
        MediaBucket.GIFTS,
        MediaBucket.TEST,
    }:
        return MAX_AVATAR_UPLOAD_BYTES

    if normalized == MediaBucket.VIBE_MEDIA:
        return MAX_MOMENT_UPLOAD_BYTES

    return MAX_AVATAR_UPLOAD_BYTES


def allowed_extensions_for_bucket(bucket: str) -> set[str]:
    normalized = bucket.strip().lower()
    if normalized == MediaBucket.VIBE_MEDIA:
        return (
            LocalMediaStorageService.allowed_image_extensions
            | LocalMediaStorageService.allowed_video_extensions
        )

    return LocalMediaStorageService.allowed_image_extensions


def allowed_content_type_prefixes_for_bucket(bucket: str) -> tuple[str, ...]:
    normalized = bucket.strip().lower()
    if normalized == MediaBucket.VIBE_MEDIA:
        return (
            *LocalMediaStorageService.image_content_type_prefixes,
            *LocalMediaStorageService.video_content_type_prefixes,
        )

    return LocalMediaStorageService.image_content_type_prefixes
