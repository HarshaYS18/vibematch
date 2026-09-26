from __future__ import annotations

import json
import subprocess
import tempfile
from datetime import datetime
from pathlib import Path

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.cdn_media import (
    CdnMediaAsset,
    CdnMediaModerationStatus,
    CdnMediaUploadStatus,
    CdnMediaVariant,
    MediaProcessingStatus,
)
from app.services import event_outbox_service, media_storage_service


IMAGE_WIDTHS = (64, 128, 256, 512, 1024)
VIDEO_RENDITIONS = (
    (360, 800),
    (540, 1400),
    (720, 2500),
)


class MediaProcessingError(RuntimeError):
    pass


def _run(command: list[str], *, timeout: int | None = None) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
            timeout=timeout or settings.MEDIA_PROCESSING_FFMPEG_TIMEOUT_SECONDS,
        )
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError) as exc:
        raise MediaProcessingError(f"Media processor failed: {command[0]}") from exc


def _upsert_variant(
    db: Session,
    *,
    asset: CdnMediaAsset,
    variant_key: str,
    kind: str,
    object_key: str,
    public_url: str,
    mime_type: str,
    size_bytes: int,
    width: int | None = None,
    height: int | None = None,
    bitrate_kbps: int | None = None,
    duration_ms: int | None = None,
) -> CdnMediaVariant:
    row = (
        db.query(CdnMediaVariant)
        .filter(
            CdnMediaVariant.media_id == asset.id,
            CdnMediaVariant.variant_key == variant_key,
        )
        .first()
    )
    if row is None:
        row = CdnMediaVariant(media_id=asset.id, variant_key=variant_key)
    row.kind = kind
    row.object_key = object_key
    row.public_url = public_url
    row.mime_type = mime_type
    row.size_bytes = int(size_bytes)
    row.width = width
    row.height = height
    row.bitrate_kbps = bitrate_kbps
    row.duration_ms = duration_ms
    db.add(row)
    return row


def _store_variant(
    db: Session,
    *,
    asset: CdnMediaAsset,
    source: Path,
    object_key: str,
    variant_key: str,
    kind: str,
    content_type: str,
    width: int | None = None,
    height: int | None = None,
    bitrate_kbps: int | None = None,
    duration_ms: int | None = None,
) -> CdnMediaVariant:
    stored = media_storage_service.store_media_file(
        source=source,
        object_key=object_key,
        content_type=content_type,
    )
    return _upsert_variant(
        db,
        asset=asset,
        variant_key=variant_key,
        kind=kind,
        object_key=stored.object_key,
        public_url=stored.public_url,
        mime_type=content_type,
        size_bytes=source.stat().st_size,
        width=width,
        height=height,
        bitrate_kbps=bitrate_kbps,
        duration_ms=duration_ms,
    )


def _process_image(db: Session, asset: CdnMediaAsset, source: Path, work: Path) -> None:
    try:
        from PIL import Image, ImageOps
    except ImportError as exc:  # pragma: no cover - runtime dependency guard
        raise MediaProcessingError("Pillow is required for image processing") from exc

    Image.MAX_IMAGE_PIXELS = settings.MEDIA_PROCESSING_MAX_IMAGE_PIXELS
    try:
        with Image.open(source) as opened:
            normalized = ImageOps.exif_transpose(opened).convert("RGB")
            source_width, source_height = normalized.size
            asset.width = int(source_width)
            asset.height = int(source_height)
            chosen_thumbnail = None
            for target_width in IMAGE_WIDTHS:
                target_height = max(1, round(source_height * target_width / source_width))
                output = work / f"w{target_width}.webp"
                resized = normalized.resize(
                    (target_width, target_height),
                    Image.Resampling.LANCZOS,
                )
                resized.save(output, format="WEBP", quality=82, method=6)
                variant = _store_variant(
                    db,
                    asset=asset,
                    source=output,
                    object_key=f"derived/{asset.public_id}/images/w{target_width}.webp",
                    variant_key=f"image_w{target_width}_webp",
                    kind="image",
                    content_type="image/webp",
                    width=target_width,
                    height=target_height,
                )
                if target_width == 256:
                    chosen_thumbnail = variant.public_url
            asset.thumbnail_url = chosen_thumbnail
    except Exception as exc:
        if isinstance(exc, MediaProcessingError):
            raise
        raise MediaProcessingError("Image derivative generation failed") from exc


def _probe_video(source: Path) -> tuple[int, int, int | None]:
    result = _run(
        [
            "ffprobe",
            "-v", "error",
            "-print_format", "json",
            "-show_streams",
            "-show_format",
            str(source),
        ]
    )
    try:
        payload = json.loads(result.stdout)
        video = next(
            stream
            for stream in payload.get("streams", [])
            if stream.get("codec_type") == "video"
        )
        width = int(video.get("width") or 0)
        height = int(video.get("height") or 0)
        duration_raw = video.get("duration") or (payload.get("format") or {}).get("duration")
        duration_ms = int(float(duration_raw) * 1000) if duration_raw else None
    except Exception as exc:
        raise MediaProcessingError("Unable to probe uploaded video") from exc
    if width <= 0 or height <= 0:
        raise MediaProcessingError("Uploaded video has invalid dimensions")
    return width, height, duration_ms


def _write_master_playlist(
    destination: Path,
    renditions: list[tuple[int, int, int]],
) -> None:
    lines = ["#EXTM3U", "#EXT-X-VERSION:7"]
    for height, width, bitrate_kbps in renditions:
        lines.extend([
            f"#EXT-X-STREAM-INF:BANDWIDTH={bitrate_kbps * 1000},RESOLUTION={width}x{height}",
            f"{height}/index.m3u8",
        ])
    destination.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _process_video(db: Session, asset: CdnMediaAsset, source: Path, work: Path) -> None:
    source_width, source_height, duration_ms = _probe_video(source)
    asset.width = source_width
    asset.height = source_height
    asset.duration_ms = duration_ms

    poster = work / "poster.webp"
    _run([
        "ffmpeg", "-y", "-ss", "1", "-i", str(source),
        "-frames:v", "1",
        "-vf", "scale=1024:-2:force_original_aspect_ratio=decrease",
        "-c:v", "libwebp", "-q:v", "80",
        str(poster),
    ])
    poster_width = min(1024, source_width)
    poster_height = max(1, round(source_height * poster_width / source_width))
    poster_variant = _store_variant(
        db,
        asset=asset,
        source=poster,
        object_key=f"derived/{asset.public_id}/poster.webp",
        variant_key="poster_webp",
        kind="poster",
        content_type="image/webp",
        width=poster_width,
        height=poster_height,
        duration_ms=duration_ms,
    )
    asset.thumbnail_url = poster_variant.public_url

    allowed = [
        (height, bitrate)
        for height, bitrate in VIDEO_RENDITIONS
        if height <= source_height
    ]
    if not allowed:
        allowed = [(source_height, 600)]
    rendered: list[tuple[int, int, int]] = []
    hls_root = work / "hls"
    hls_root.mkdir(parents=True, exist_ok=True)

    for height, bitrate_kbps in allowed:
        width = max(2, round((source_width * height / source_height) / 2) * 2)
        rendition = hls_root / str(height)
        rendition.mkdir(parents=True, exist_ok=True)
        playlist = rendition / "index.m3u8"
        segment_pattern = rendition / "segment_%05d.m4s"
        _run([
            "ffmpeg", "-y", "-i", str(source),
            "-vf", f"scale=-2:{height}",
            "-c:v", "libx264", "-preset", "veryfast", "-profile:v", "main",
            "-crf", "22",
            "-c:a", "aac", "-b:a", "128k", "-ac", "2", "-ar", "48000",
            "-f", "hls",
            "-hls_time", "4",
            "-hls_playlist_type", "vod",
            "-hls_segment_type", "fmp4",
            "-hls_fmp4_init_filename", "init.mp4",
            "-hls_segment_filename", str(segment_pattern),
            str(playlist),
        ])
        prefix = f"derived/{asset.public_id}/hls/{height}"
        for generated in sorted(rendition.iterdir()):
            content_type = (
                "application/vnd.apple.mpegurl"
                if generated.suffix == ".m3u8"
                else "video/mp4"
            )
            media_storage_service.store_media_file(
                source=generated,
                object_key=f"{prefix}/{generated.name}",
                content_type=content_type,
            )
        playlist_url = media_storage_service.public_url_for_object(
            object_key=f"{prefix}/index.m3u8",
            request_base_url="http://127.0.0.1:8000",
        )
        _upsert_variant(
            db,
            asset=asset,
            variant_key=f"hls_{height}",
            kind="hls_playlist",
            object_key=f"{prefix}/index.m3u8",
            public_url=playlist_url,
            mime_type="application/vnd.apple.mpegurl",
            size_bytes=playlist.stat().st_size,
            width=width,
            height=height,
            bitrate_kbps=bitrate_kbps,
            duration_ms=duration_ms,
        )
        rendered.append((height, width, bitrate_kbps))

    master = hls_root / "master.m3u8"
    _write_master_playlist(master, rendered)
    master_key = f"derived/{asset.public_id}/hls/master.m3u8"
    master_variant = _store_variant(
        db,
        asset=asset,
        source=master,
        object_key=master_key,
        variant_key="hls_master",
        kind="hls_master",
        content_type="application/vnd.apple.mpegurl",
        duration_ms=duration_ms,
    )
    metadata = dict(asset.metadata_json or {})
    metadata["hls_master_url"] = master_variant.public_url
    metadata["hls_renditions"] = [height for height, _, _ in rendered]
    asset.metadata_json = metadata


def process_uploaded_media(
    db: Session,
    *,
    media_id: str,
    actor_user_id: int | None,
) -> bool:
    asset = (
        db.query(CdnMediaAsset)
        .filter(CdnMediaAsset.public_id == media_id)
        .first()
    )
    if asset is None:
        raise ValueError("Media asset not found")
    if asset.processing_status == MediaProcessingStatus.READY.value:
        return True
    if asset.upload_status not in {
        CdnMediaUploadStatus.PROCESSING.value,
        CdnMediaUploadStatus.PROCESSING_FAILED.value,
    }:
        raise MediaProcessingError("Media asset is not ready for processing")

    asset.processing_status = MediaProcessingStatus.PROCESSING.value
    asset.processing_started_at = datetime.utcnow()
    asset.processing_error = None
    db.add(asset)
    db.commit()

    try:
        with tempfile.TemporaryDirectory(prefix="funkey-media-") as temp_dir:
            work = Path(temp_dir)
            suffix = Path(asset.object_key).suffix or ".bin"
            source = work / f"source{suffix}"
            media_storage_service.download_media_object_to_path(
                object_key=asset.object_key,
                destination=source,
            )
            if asset.mime_type.startswith("image/"):
                _process_image(db, asset, source, work)
            elif asset.mime_type.startswith("video/"):
                _process_video(db, asset, source, work)

        asset.processing_status = MediaProcessingStatus.READY.value
        asset.processing_completed_at = datetime.utcnow()
        asset.processing_error = None
        if asset.moderation_status == CdnMediaModerationStatus.PENDING.value:
            asset.upload_status = CdnMediaUploadStatus.MODERATION_PENDING.value
            event_outbox_service.enqueue_event(
                db,
                event_type="media.moderation.requested",
                actor_user_id=actor_user_id,
                payload={"media_id": asset.public_id},
            )
        else:
            asset.upload_status = CdnMediaUploadStatus.APPROVED.value
            asset.is_active_reference = True
        db.add(asset)
        db.commit()
        return False
    except Exception as exc:
        db.rollback()
        asset = (
            db.query(CdnMediaAsset)
            .filter(CdnMediaAsset.public_id == media_id)
            .first()
        )
        if asset is not None:
            asset.processing_status = MediaProcessingStatus.FAILED.value
            asset.upload_status = CdnMediaUploadStatus.PROCESSING_FAILED.value
            asset.processing_error = type(exc).__name__[:200]
            db.add(asset)
            db.commit()
        raise
