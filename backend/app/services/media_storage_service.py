from __future__ import annotations

import math
import mimetypes
import os
import shutil
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import quote

from app.core.config import settings


@dataclass(frozen=True)
class StoredMediaObject:
    object_key: str
    public_url: str
    storage_driver: str


@dataclass(frozen=True)
class DirectUploadPart:
    part_number: int
    url: str
    headers: dict[str, str]


@dataclass(frozen=True)
class DirectUploadPlan:
    mode: str
    upload_url: str | None
    headers: dict[str, str]
    upload_id: str | None
    part_size_bytes: int | None
    parts: tuple[DirectUploadPart, ...]


@dataclass(frozen=True)
class MediaObjectHead:
    size_bytes: int
    content_type: str | None
    etag: str | None


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


def storage_driver() -> str:
    return (settings.MEDIA_STORAGE_DRIVER or "local").strip().lower()


def public_url_for_object(*, object_key: str, request_base_url: str) -> str:
    driver = storage_driver()
    if driver == "local":
        return _local_public_url(request_base_url, object_key)
    if driver == "s3":
        return _cdn_public_url(object_key)
    raise MediaStorageError(f"Unsupported MEDIA_STORAGE_DRIVER: {driver}")


def local_object_path(object_key: str) -> Path:
    normalized = object_key.replace("\\", "/").lstrip("/")
    if ".." in Path(normalized).parts:
        raise MediaStorageError("Invalid media object key")
    path = Path("static/uploads") / normalized
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def _s3_client():
    try:
        import boto3  # type: ignore
        from botocore.config import Config  # type: ignore
    except Exception as exc:  # pragma: no cover
        raise MediaStorageError("boto3 is required when MEDIA_STORAGE_DRIVER=s3") from exc
    session = boto3.session.Session(
        aws_access_key_id=settings.MEDIA_S3_ACCESS_KEY_ID or None,
        aws_secret_access_key=settings.MEDIA_S3_SECRET_ACCESS_KEY or None,
        region_name=settings.MEDIA_S3_REGION or None,
    )
    return session.client(
        "s3",
        endpoint_url=settings.MEDIA_S3_ENDPOINT_URL or None,
        config=Config(signature_version="s3v4"),
    )


def _require_s3_bucket() -> str:
    bucket = settings.MEDIA_S3_BUCKET.strip()
    if not bucket:
        raise MediaStorageError("MEDIA_S3_BUCKET is required when MEDIA_STORAGE_DRIVER=s3")
    return bucket


def create_direct_upload(
    *,
    object_key: str,
    content_type: str,
    size_bytes: int,
    expires_seconds: int,
) -> DirectUploadPlan:
    if storage_driver() != "s3":
        raise MediaStorageError("Direct presigned upload requires s3 storage")
    bucket = _require_s3_bucket()
    client = _s3_client()
    threshold = max(
        settings.MEDIA_MULTIPART_PART_SIZE_BYTES,
        settings.MEDIA_MULTIPART_THRESHOLD_BYTES,
    )
    headers = {"Content-Type": content_type}
    if size_bytes < threshold:
        url = client.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": bucket,
                "Key": object_key,
                "ContentType": content_type,
            },
            ExpiresIn=expires_seconds,
        )
        return DirectUploadPlan(
            mode="single_put",
            upload_url=url,
            headers=headers,
            upload_id=None,
            part_size_bytes=None,
            parts=(),
        )

    part_size = max(5 * 1024 * 1024, settings.MEDIA_MULTIPART_PART_SIZE_BYTES)
    part_count = int(math.ceil(size_bytes / part_size))
    if part_count > settings.MEDIA_DIRECT_UPLOAD_MAX_PARTS:
        raise MediaStorageError("Media upload requires too many multipart parts")

    created = client.create_multipart_upload(
        Bucket=bucket,
        Key=object_key,
        ContentType=content_type,
        CacheControl="public, max-age=31536000, immutable",
    )
    upload_id = str(created["UploadId"])
    parts = tuple(
        DirectUploadPart(
            part_number=part_number,
            url=client.generate_presigned_url(
                "upload_part",
                Params={
                    "Bucket": bucket,
                    "Key": object_key,
                    "UploadId": upload_id,
                    "PartNumber": part_number,
                },
                ExpiresIn=expires_seconds,
            ),
            headers={},
        )
        for part_number in range(1, part_count + 1)
    )
    return DirectUploadPlan(
        mode="multipart",
        upload_url=None,
        headers={},
        upload_id=upload_id,
        part_size_bytes=part_size,
        parts=parts,
    )


def complete_multipart_upload(
    *,
    object_key: str,
    upload_id: str,
    parts: list[dict[str, object]],
) -> None:
    client = _s3_client()
    client.complete_multipart_upload(
        Bucket=_require_s3_bucket(),
        Key=object_key,
        UploadId=upload_id,
        MultipartUpload={
            "Parts": [
                {
                    "PartNumber": int(part["part_number"]),
                    "ETag": str(part["etag"]),
                }
                for part in parts
            ]
        },
    )


def abort_multipart_upload(*, object_key: str, upload_id: str) -> None:
    if storage_driver() != "s3" or not upload_id:
        return
    try:
        _s3_client().abort_multipart_upload(
            Bucket=_require_s3_bucket(),
            Key=object_key,
            UploadId=upload_id,
        )
    except Exception as exc:
        response = getattr(exc, "response", None)
        error = response.get("Error") if isinstance(response, dict) else None
        if isinstance(error, dict) and error.get("Code") == "NoSuchUpload":
            return
        raise


def head_media_object(object_key: str) -> MediaObjectHead:
    driver = storage_driver()
    if driver == "local":
        path = local_object_path(object_key)
        if not path.is_file():
            raise MediaStorageError("Uploaded media object was not found")
        return MediaObjectHead(
            size_bytes=path.stat().st_size,
            content_type=mimetypes.guess_type(object_key)[0],
            etag=None,
        )
    if driver == "s3":
        response = _s3_client().head_object(
            Bucket=_require_s3_bucket(),
            Key=object_key,
        )
        return MediaObjectHead(
            size_bytes=int(response.get("ContentLength") or 0),
            content_type=(
                str(response.get("ContentType")).split(";", 1)[0].strip().lower()
                if response.get("ContentType")
                else None
            ),
            etag=str(response.get("ETag") or "").strip('"') or None,
        )
    raise MediaStorageError(f"Unsupported MEDIA_STORAGE_DRIVER: {driver}")


def download_media_object_to_path(*, object_key: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    driver = storage_driver()
    if driver == "local":
        source = local_object_path(object_key)
        if not source.is_file():
            raise MediaStorageError("Media source object not found")
        shutil.copyfile(source, destination)
        return
    if driver == "s3":
        _s3_client().download_file(
            _require_s3_bucket(),
            object_key,
            str(destination),
        )
        return
    raise MediaStorageError(f"Unsupported MEDIA_STORAGE_DRIVER: {driver}")


def store_media_file(
    *,
    source: Path,
    object_key: str,
    content_type: str,
    request_base_url: str = "",
) -> StoredMediaObject:
    driver = storage_driver()
    if driver == "local":
        destination = local_object_path(object_key)
        shutil.copyfile(source, destination)
        return StoredMediaObject(
            object_key=object_key,
            public_url=_local_public_url(request_base_url or "http://127.0.0.1:8000", object_key),
            storage_driver="local",
        )
    if driver == "s3":
        extra_args = {
            "ContentType": content_type,
            "CacheControl": "public, max-age=31536000, immutable",
        }
        if settings.MEDIA_S3_PUBLIC_READ:
            extra_args["ACL"] = "public-read"
        _s3_client().upload_file(
            str(source),
            _require_s3_bucket(),
            object_key,
            ExtraArgs=extra_args,
        )
        return StoredMediaObject(
            object_key=object_key,
            public_url=_cdn_public_url(object_key),
            storage_driver="s3",
        )
    raise MediaStorageError(f"Unsupported MEDIA_STORAGE_DRIVER: {driver}")
