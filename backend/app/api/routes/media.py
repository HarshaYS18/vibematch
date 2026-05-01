from fastapi import APIRouter, File, UploadFile

from app.core.upload_limits import bytes_to_mb
from app.schemas.media import MediaUploadResponse
from app.services.media_storage_service import (
    MediaBucket,
    allowed_content_type_prefixes_for_bucket,
    allowed_extensions_for_bucket,
    max_size_for_bucket,
    media_storage_service,
)

router = APIRouter(prefix="/media-api", tags=["media"])


@router.get("/health")
def media_health():
    return {
        "status": "ok",
        "storage_backend": media_storage_service.__class__.__name__,
        "message": "Local laptop CDN media API is running.",
    }


@router.post("/upload/avatar", response_model=MediaUploadResponse)
async def upload_avatar(file: UploadFile = File(...)):
    return await _save_media_upload(file=file, bucket=MediaBucket.AVATARS)


@router.post("/upload/room-image", response_model=MediaUploadResponse)
async def upload_room_image(file: UploadFile = File(...)):
    return await _save_media_upload(file=file, bucket=MediaBucket.ROOM_IMAGES)


@router.post("/upload/room-background", response_model=MediaUploadResponse)
async def upload_room_background(file: UploadFile = File(...)):
    return await _save_media_upload(file=file, bucket=MediaBucket.ROOM_BACKGROUNDS)


@router.post("/upload/chat-image", response_model=MediaUploadResponse)
async def upload_chat_image(file: UploadFile = File(...)):
    return await _save_media_upload(file=file, bucket=MediaBucket.CHAT_IMAGES)


@router.post("/upload/vibe-media", response_model=MediaUploadResponse)
async def upload_vibe_media(file: UploadFile = File(...)):
    return await _save_media_upload(file=file, bucket=MediaBucket.VIBE_MEDIA)


@router.post("/upload/test", response_model=MediaUploadResponse)
async def upload_test_media(file: UploadFile = File(...)):
    return await _save_media_upload(file=file, bucket=MediaBucket.TEST)


async def _save_media_upload(*, file: UploadFile, bucket: str) -> MediaUploadResponse:
    stored = await media_storage_service.save_upload(
        file=file,
        bucket=bucket,
        allowed_extensions=allowed_extensions_for_bucket(bucket),
        allowed_content_type_prefixes=allowed_content_type_prefixes_for_bucket(bucket),
        max_size_bytes=max_size_for_bucket(bucket),
    )

    return MediaUploadResponse(
        storage_backend=stored.storage_backend,
        storage_key=stored.storage_key,
        public_url=stored.public_url,
        filename=stored.filename,
        content_type=stored.content_type,
        size_bytes=stored.size_bytes,
        size_mb=bytes_to_mb(stored.size_bytes),
        bucket=stored.bucket,
    )
