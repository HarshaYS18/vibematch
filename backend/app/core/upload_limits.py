# app/core/upload_limits.py

"""
Central upload size limits for VibeMatch.

Rules:
- Avatar/profile picture uploads must be less than 10 MB.
- Dynamic avatar/GIF avatar uploads must be less than 10 MB.
- Moment media uploads must be max 20 MB.
"""

MB = 1024 * 1024

MAX_AVATAR_UPLOAD_BYTES = 10 * MB
MAX_DYNAMIC_AVATAR_UPLOAD_BYTES = 10 * MB
MAX_MOMENT_UPLOAD_BYTES = 20 * MB


def bytes_to_mb(size_bytes: int) -> float:
    return round(size_bytes / MB, 2)


def validate_avatar_upload_size(size_bytes: int) -> None:
    if size_bytes >= MAX_AVATAR_UPLOAD_BYTES:
        from fastapi import HTTPException

        raise HTTPException(
            status_code=413,
            detail="Avatar file must be less than 10 MB.",
        )


def validate_dynamic_avatar_upload_size(size_bytes: int) -> None:
    if size_bytes >= MAX_DYNAMIC_AVATAR_UPLOAD_BYTES:
        from fastapi import HTTPException

        raise HTTPException(
            status_code=413,
            detail="Dynamic avatar file must be less than 10 MB.",
        )


def validate_moment_upload_size(size_bytes: int) -> None:
    if size_bytes > MAX_MOMENT_UPLOAD_BYTES:
        from fastapi import HTTPException

        raise HTTPException(
            status_code=413,
            detail="Moment media file must be 20 MB or less.",
        )