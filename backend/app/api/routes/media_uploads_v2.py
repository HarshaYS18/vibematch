from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.cdn_media import MediaUploadMode
from app.models.user import User
from app.schemas.media_v2 import (
    MediaAssetStatusResponse,
    MediaDirectUploadPartResponse,
    MediaUploadCompleteRequest,
    MediaUploadSessionCreateRequest,
    MediaUploadSessionResponse,
    MediaVariantResponse,
)
from app.services import media_storage_service, media_upload_session_service

router = APIRouter(prefix="/media", tags=["Media v2"])


def _status_response(asset, variants) -> MediaAssetStatusResponse:
    return MediaAssetStatusResponse(
        media_id=asset.public_id,
        url=asset.public_url,
        thumbnail_url=asset.thumbnail_url,
        content_type=asset.mime_type,
        size_bytes=int(asset.size_bytes or 0),
        upload_status=asset.upload_status,
        processing_status=asset.processing_status,
        moderation_status=asset.moderation_status,
        expires_at=asset.expires_at,
        variants=[
            MediaVariantResponse(
                variant_key=item.variant_key,
                kind=item.kind,
                url=item.public_url,
                content_type=item.mime_type,
                width=item.width,
                height=item.height,
                bitrate_kbps=item.bitrate_kbps,
                size_bytes=int(item.size_bytes or 0),
            )
            for item in variants
        ],
    )


@router.post("/upload-sessions", response_model=MediaUploadSessionResponse)
def create_upload_session(
    payload: MediaUploadSessionCreateRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        session, asset, plan = media_upload_session_service.create_upload_session(
            db,
            owner=current_user,
            purpose=payload.purpose,
            filename=payload.filename,
            content_type=payload.content_type,
            size_bytes=payload.size_bytes,
            request_base_url=str(request.base_url),
        )
    except media_upload_session_service.MediaUploadSessionError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except media_storage_service.MediaStorageError as exc:
        raise HTTPException(status_code=503, detail="Media storage unavailable") from exc

    upload_url = plan.upload_url if plan else None
    upload_headers = dict(plan.headers) if plan else {}
    parts = (
        [
            MediaDirectUploadPartResponse(
                part_number=item.part_number,
                url=item.url,
                headers=dict(item.headers),
            )
            for item in plan.parts
        ]
        if plan
        else []
    )
    if session.upload_mode == MediaUploadMode.LOCAL_STREAM.value:
        upload_url = (
            str(request.base_url).rstrip("/")
            + f"/api/v1/media/upload-sessions/{session.public_id}/content"
        )
        upload_headers = {"Content-Type": session.expected_mime_type}

    return MediaUploadSessionResponse(
        session_id=session.public_id,
        media_id=asset.public_id,
        upload_mode=session.upload_mode,
        upload_url=upload_url,
        upload_headers=upload_headers,
        part_size_bytes=session.part_size_bytes,
        parts=parts,
        expires_at=session.expires_at,
    )


@router.put("/upload-sessions/{session_id}/content")
async def upload_local_session_content(
    session_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        session = media_upload_session_service.get_owned_session(
            db,
            owner_user_id=current_user.id,
            session_id=session_id,
        )
        if session.upload_mode != MediaUploadMode.LOCAL_STREAM.value:
            raise media_upload_session_service.MediaUploadSessionError(
                "Local upload endpoint is disabled for this session"
            )
        destination = media_storage_service.local_object_path(session.object_key)
        bytes_written = 0
        with destination.open("wb") as output:
            async for chunk in request.stream():
                if not chunk:
                    continue
                bytes_written += len(chunk)
                if bytes_written > int(session.expected_size_bytes):
                    output.close()
                    destination.unlink(missing_ok=True)
                    raise media_upload_session_service.MediaUploadSessionError(
                        "Uploaded media exceeds the declared size"
                    )
                output.write(chunk)
        media_upload_session_service.mark_local_stream_uploaded(
            db,
            session=session,
            bytes_written=bytes_written,
        )
    except media_upload_session_service.MediaUploadSessionError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except media_storage_service.MediaStorageError as exc:
        raise HTTPException(status_code=503, detail="Media storage unavailable") from exc
    return {"uploaded": True, "bytes_written": bytes_written}


@router.post(
    "/upload-sessions/{session_id}/complete",
    response_model=MediaAssetStatusResponse,
)
def complete_upload_session(
    session_id: str,
    payload: MediaUploadCompleteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        asset, _ = media_upload_session_service.complete_upload_session(
            db,
            owner_user_id=current_user.id,
            session_id=session_id,
            parts=[
                {"part_number": item.part_number, "etag": item.etag}
                for item in payload.parts
            ],
        )
        asset, variants = media_upload_session_service.media_status(
            db,
            owner_user_id=current_user.id,
            media_id=asset.public_id,
        )
    except media_upload_session_service.MediaUploadSessionError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except media_storage_service.MediaStorageError as exc:
        raise HTTPException(status_code=503, detail="Media storage unavailable") from exc
    return _status_response(asset, variants)


@router.get("/{media_id}/status", response_model=MediaAssetStatusResponse)
def get_media_status(
    media_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        asset, variants = media_upload_session_service.media_status(
            db,
            owner_user_id=current_user.id,
            media_id=media_id,
        )
    except media_upload_session_service.MediaUploadSessionError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return _status_response(asset, variants)
