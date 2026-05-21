from __future__ import annotations

import mimetypes
import os
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import quote

from app.core.config import settings


@dataclass(frozen=True)
class StoredMediaObject:
    object_key: str
    public_url: str
    storage_driver: str


class MediaStorageError(RuntimeError):
    pass


def _clean_base_url(value: str) -> str:
    return (value or "").strip().rstrip("/")


def _local_public_url(request_base_url: str, object_key: str) -> str:
    base = request_base_url.rstrip("/")
    return f"{base}/static/uploads/{object_key}"


def _cdn_public_url(object_key: str) -> str:
    base = _clean_base_url(settings.MEDIA_CDN_BASE_URL)
    if not base:
        raise MediaStorageError("MEDIA_CDN_BASE_URL is required for production media storage")
    return f"{base}/{quote(object_key)}"


def store_media_bytes(*, data: bytes, object_key: str, content_type: str, request_base_url: str) -> StoredMediaObject:
    driver = (settings.MEDIA_STORAGE_DRIVER or "local").strip().lower()
    if driver == "local":
        path = Path("static/uploads") / object_key
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return StoredMediaObject(object_key=object_key, public_url=_local_public_url(request_base_url, object_key), storage_driver="local")
    if driver == "s3":
        return _store_s3(data=data, object_key=object_key, content_type=content_type)
    raise MediaStorageError(f"Unsupported MEDIA_STORAGE_DRIVER: {driver}")


def delete_media_object(object_key: str | None) -> None:
    if not object_key:
        return
    driver = (settings.MEDIA_STORAGE_DRIVER or "local").strip().lower()
    if driver == "local":
        normalized = object_key.replace("\\", "/").lstrip("/")
        if ".." in Path(normalized).parts:
            return
        path = Path("static/uploads") / normalized
        if path.exists() and path.is_file():
            path.unlink()
        return
    if driver == "s3":
        _delete_s3(object_key)


def _store_s3(*, data: bytes, object_key: str, content_type: str) -> StoredMediaObject:
    try:
        import boto3  # type: ignore
    except Exception as exc:  # pragma: no cover - dependency guard
        raise MediaStorageError("boto3 is required when MEDIA_STORAGE_DRIVER=s3") from exc

    bucket = settings.MEDIA_S3_BUCKET.strip()
    if not bucket:
        raise MediaStorageError("MEDIA_S3_BUCKET is required when MEDIA_STORAGE_DRIVER=s3")
    session = boto3.session.Session(
        aws_access_key_id=settings.MEDIA_S3_ACCESS_KEY_ID or None,
        aws_secret_access_key=settings.MEDIA_S3_SECRET_ACCESS_KEY or None,
        region_name=settings.MEDIA_S3_REGION or None,
    )
    client = session.client("s3", endpoint_url=settings.MEDIA_S3_ENDPOINT_URL or None)
    extra_args = {
        "ContentType": content_type or mimetypes.guess_type(object_key)[0] or "application/octet-stream",
        "CacheControl": "public, max-age=31536000, immutable",
    }
    if settings.MEDIA_S3_PUBLIC_READ:
        extra_args["ACL"] = "public-read"
    client.put_object(Bucket=bucket, Key=object_key, Body=data, **extra_args)
    return StoredMediaObject(object_key=object_key, public_url=_cdn_public_url(object_key), storage_driver="s3")


def _delete_s3(object_key: str) -> None:
    try:
        import boto3  # type: ignore
    except Exception as exc:  # pragma: no cover - dependency guard
        raise MediaStorageError("boto3 is required when MEDIA_STORAGE_DRIVER=s3") from exc
    bucket = settings.MEDIA_S3_BUCKET.strip()
    if not bucket:
        raise MediaStorageError("MEDIA_S3_BUCKET is required when MEDIA_STORAGE_DRIVER=s3")
    session = boto3.session.Session(
        aws_access_key_id=settings.MEDIA_S3_ACCESS_KEY_ID or None,
        aws_secret_access_key=settings.MEDIA_S3_SECRET_ACCESS_KEY or None,
        region_name=settings.MEDIA_S3_REGION or None,
    )
    client = session.client("s3", endpoint_url=settings.MEDIA_S3_ENDPOINT_URL or None)
    client.delete_object(Bucket=bucket, Key=object_key)
