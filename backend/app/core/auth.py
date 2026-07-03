# SPDX-License-Identifier: AGPL-3.0-only
"""PocketBase トークン検証(docs/03)。

- ミドルウェアが Bearer トークンを auth-refresh で検証し、
  request.state.user_id に PocketBase ID を格納する(無認証なら None)
- 検証結果は数分間メモリキャッシュする
- require_user 依存性が shared.app_users を初回アクセス時に自動作成する
"""

import time
from dataclasses import dataclass

import httpx
from fastapi import Depends, Request
from sqlalchemy.orm import Session
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.responses import Response

from app.core.config import settings
from app.core.db import get_db
from app.core.errors import ApiError

CACHE_TTL = 300  # 秒


@dataclass
class Identity:
    """PocketBase が返す身元(業務データは持たない)。"""

    user_id: str
    display_name: str


_cache: dict[str, tuple[float, Identity]] = {}


def _cached(token: str) -> Identity | None:
    hit = _cache.get(token)
    if hit and time.monotonic() - hit[0] < CACHE_TTL:
        return hit[1]
    return None


async def verify_token(token: str) -> Identity | None:
    """PocketBase の auth-refresh 相当でトークンを検証する。"""
    if identity := _cached(token):
        return identity
    url = f"{settings().pocketbase_url}/api/collections/users/auth-refresh"
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            res = await client.post(url, headers={"Authorization": f"Bearer {token}"})
    except httpx.HTTPError:
        return None
    if res.status_code != 200:
        return None
    record = res.json().get("record", {})
    email = record.get("email", "")
    identity = Identity(
        user_id=record.get("id", ""),
        display_name=record.get("name") or email.split("@")[0] or "名無し",
    )
    if not identity.user_id:
        return None
    _cache[token] = (time.monotonic(), identity)
    return identity


class AuthMiddleware(BaseHTTPMiddleware):
    """Bearer トークンがあれば検証し request.state に載せる。

    閲覧系は認証不要のため、トークンが無い/無効でもここでは拒否しない。
    認証必須のエンドポイントは require_user 依存性で 401 を返す。
    """

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        request.state.user_id = None
        request.state.identity = None
        auth = request.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            identity = await verify_token(auth.removeprefix("Bearer "))
            if identity is not None:
                request.state.user_id = identity.user_id
                request.state.identity = identity
        return await call_next(request)


def require_user(request: Request, db: Session = Depends(get_db)) -> str:
    """認証必須エンドポイント用。app_users を自動作成して user_id を返す。"""
    from app.models import AppUser  # 循環 import 回避

    identity: Identity | None = getattr(request.state, "identity", None)
    if identity is None:
        raise ApiError(401, "UNAUTHENTICATED", "ログインが必要です")
    user = db.get(AppUser, identity.user_id)
    if user is None:
        user = AppUser(id=identity.user_id, display_name=identity.display_name)
        db.add(user)
        db.commit()
    if user.is_suspended:
        raise ApiError(403, "SUSPENDED", "アカウントが停止されています")
    return identity.user_id
