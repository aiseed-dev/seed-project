# SPDX-License-Identifier: AGPL-3.0-only
"""出品写真の保存。長辺 1600px に縮小してローカルディスクへ置く。"""

import io
import uuid
from pathlib import Path

from PIL import Image, UnidentifiedImageError

from app.core.config import settings
from app.core.errors import ApiError

MAX_BYTES = 10 * 1024 * 1024
MAX_EDGE = 1600
FORMATS = {"JPEG": ".jpg", "PNG": ".png", "WEBP": ".webp"}


def save_listing_photo(listing_id: uuid.UUID, data: bytes) -> str:
    """検証・縮小して保存し、相対パスを返す。"""
    if len(data) > MAX_BYTES:
        raise ApiError(422, "PHOTO_TOO_LARGE", "写真は10MBまでです")
    try:
        image = Image.open(io.BytesIO(data))
        image.load()
    except UnidentifiedImageError:
        raise ApiError(
            422, "PHOTO_FORMAT", "JPEG / PNG / WebP の画像を指定してください"
        ) from None
    fmt = image.format
    if fmt not in FORMATS:
        raise ApiError(
            422, "PHOTO_FORMAT", "JPEG / PNG / WebP の画像を指定してください"
        )

    if max(image.size) > MAX_EDGE:
        image.thumbnail((MAX_EDGE, MAX_EDGE))

    relative = Path("listings") / str(listing_id) / f"{uuid.uuid4()}{FORMATS[fmt]}"
    target = settings().images_dir / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target)
    return str(relative)


def delete_photo_file(relative: str) -> None:
    path = settings().images_dir / relative
    path.unlink(missing_ok=True)
