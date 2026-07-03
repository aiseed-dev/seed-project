# SPDX-License-Identifier: AGPL-3.0-only
"""QRコード生成(docs/03・公開)。紙・実物とアプリをつなぐ入口。

中身はURLのみ。go_router のディープリンクで開く。
サイズ・余白は印刷を想定した既定値(300px・quiet zone 4)。
"""

import io

import segno
from fastapi import APIRouter, Query
from fastapi.responses import Response

from app.core.config import settings

router = APIRouter(tags=["qr"])

PATHS = {
    "v": "v",  # 品種ページ(種袋・店頭POP → 辞典)
    "l": "l",  # 出品ページ(店頭の現物棚 → 出品詳細)
    "c": "c",  # 品目ページ(aiseed の品目ハブ)
    "r": "r",  # 申込み(同梱票 → 申込み画面)
}


def _png(url: str, size: int) -> bytes:
    qr = segno.make(url, error="m")
    scale = max(1, size // (qr.symbol_size()[0] + 8))  # quiet zone 4×2
    buffer = io.BytesIO()
    qr.save(buffer, kind="png", scale=scale, border=4)
    return buffer.getvalue()


@router.get("/qr/{kind}/{target}.png")
def qr_png(
    kind: str,
    target: str,
    size: int = Query(default=300, ge=100, le=1200),
) -> Response:
    if kind not in PATHS:
        from app.core.errors import ApiError

        raise ApiError(404, "NOT_FOUND", "QRの種類が不正です")
    url = f"{settings().public_app_url}/{PATHS[kind]}/{target}"
    return Response(content=_png(url, size), media_type="image/png")
