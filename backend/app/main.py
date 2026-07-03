# SPDX-License-Identifier: AGPL-3.0-only
"""種の交換アプリ バックエンド(FastAPI)。

Phase 1: 認証・分類・出品・品種検索。
残るルーター(cart, requests, crops, editor, shop, qr)は docs/03 に
従い以降のフェーズで追加する。
"""

from fastapi import FastAPI

from app.core.auth import AuthMiddleware
from app.core.errors import install_handlers
from app.routers import (
    articles,
    cart,
    categories,
    editor,
    listings,
    me,
    reports,
    requests,
    varieties,
)

app = FastAPI(title="seed backend", version="0.1.0")
app.add_middleware(AuthMiddleware)
install_handlers(app)

app.include_router(categories.router, prefix="/api/v1")
app.include_router(listings.router, prefix="/api/v1")
app.include_router(varieties.router, prefix="/api/v1")
app.include_router(cart.router, prefix="/api/v1")
app.include_router(requests.router, prefix="/api/v1")
app.include_router(reports.router, prefix="/api/v1")
app.include_router(articles.router, prefix="/api/v1")
app.include_router(editor.router, prefix="/api/v1")
app.include_router(me.router, prefix="/api/v1")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
