# SPDX-License-Identifier: AGPL-3.0-only
import httpx
import psycopg
import pytest

from tests.conftest import TEST_DSN, auth

BODY = {
    "variety_name_free": "テスト品種",
    "category_id": 1,
    "title": "テスト出品",
    "listing_type": "give",
    "non_registered_confirmed": True,
}


@pytest.mark.anyio
async def test_401_without_token(client: httpx.AsyncClient) -> None:
    res = await client.post("/api/v1/listings", json=BODY)
    assert res.status_code == 401
    assert res.json()["code"] == "UNAUTHENTICATED"


@pytest.mark.anyio
async def test_401_with_invalid_token(client: httpx.AsyncClient) -> None:
    res = await client.post(
        "/api/v1/listings", json=BODY, headers={"Authorization": "Bearer bad"}
    )
    assert res.status_code == 401


@pytest.mark.anyio
async def test_app_user_auto_created(client: httpx.AsyncClient) -> None:
    res = await client.post("/api/v1/listings", json=BODY, headers=auth("newuser"))
    assert res.status_code == 201
    with psycopg.connect(TEST_DSN) as conn:
        row = conn.execute(
            "SELECT display_name FROM shared.app_users WHERE id = 'newuser'"
        ).fetchone()
    assert row == ("テストnewuser",)


@pytest.mark.anyio
async def test_suspended_user_403(client: httpx.AsyncClient) -> None:
    with psycopg.connect(TEST_DSN, autocommit=True) as conn:
        conn.execute(
            "INSERT INTO shared.app_users (id, display_name, is_suspended)"
            " VALUES ('banned', '停止中', true)"
        )
    res = await client.post("/api/v1/listings", json=BODY, headers=auth("banned"))
    assert res.status_code == 403
    assert res.json()["code"] == "SUSPENDED"
