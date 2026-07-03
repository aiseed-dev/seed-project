# SPDX-License-Identifier: AGPL-3.0-only
"""種の交換アプリ バックエンド(FastAPI)。

Phase 0: 雛形。ルーター(listings, cart, requests, varieties, crops,
editor, shop, qr)は docs/03 の仕様に従い Phase 1 以降で追加する。
"""

from fastapi import FastAPI

app = FastAPI(title="seed backend", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
