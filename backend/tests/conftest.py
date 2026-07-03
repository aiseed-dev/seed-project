# SPDX-License-Identifier: AGPL-3.0-only
"""テスト設定。ローカルの PostgreSQL に専用 DB(seed_test)を作って使う。"""

import os
import sys
import tempfile
from collections.abc import AsyncIterator, Iterator
from pathlib import Path

import httpx
import psycopg
import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

TEST_DSN = os.environ.get(
    "SEED_TEST_DSN", "postgresql://seed:seed@localhost:5432/seed_test"
)
os.environ["seed_database_url"] = TEST_DSN.replace(
    "postgresql://", "postgresql+psycopg://"
)
os.environ["seed_images_dir"] = tempfile.mkdtemp(prefix="seed-images-")


@pytest.fixture
def anyio_backend() -> str:
    return "asyncio"


def _ensure_database() -> None:
    admin_dsn = TEST_DSN.rsplit("/", 1)[0] + "/postgres"
    dbname = TEST_DSN.rsplit("/", 1)[1]
    with psycopg.connect(admin_dsn, autocommit=True) as conn:
        exists = conn.execute(
            "SELECT 1 FROM pg_database WHERE datname = %s", (dbname,)
        ).fetchone()
        if not exists:
            conn.execute(f'CREATE DATABASE "{dbname}"')


@pytest.fixture(scope="session", autouse=True)
def database() -> Iterator[None]:
    _ensure_database()
    from scripts.initdb import apply_schema

    with psycopg.connect(TEST_DSN, autocommit=True) as conn:
        conn.execute("DROP SCHEMA IF EXISTS shared, exchange, dictionary CASCADE")
    apply_schema(TEST_DSN)
    yield


@pytest.fixture(autouse=True)
def clean_tables(database: None) -> Iterator[None]:
    yield
    with psycopg.connect(TEST_DSN, autocommit=True) as conn:
        conn.execute(
            "TRUNCATE shared.app_users, shared.crops, shared.varieties,"
            " shared.shops CASCADE"
        )


@pytest.fixture
def fake_pocketbase(monkeypatch: pytest.MonkeyPatch) -> None:
    """`tok-<user_id>` 形式のトークンを常に有効とみなす偽の検証。"""
    from app.core.auth import Identity, _cache

    _cache.clear()

    async def fake_verify(token: str) -> Identity | None:
        if token.startswith("tok-"):
            user_id = token.removeprefix("tok-")
            return Identity(user_id=user_id, display_name=f"テスト{user_id}")
        return None

    monkeypatch.setattr("app.core.auth.verify_token", fake_verify)


@pytest.fixture
async def client(fake_pocketbase: None) -> AsyncIterator[httpx.AsyncClient]:
    from app.main import app

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://t") as c:
        yield c


def auth(user_id: str = "u1") -> dict[str, str]:
    return {"Authorization": f"Bearer tok-{user_id}"}
