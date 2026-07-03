# SPDX-License-Identifier: AGPL-3.0-only
"""出品 API: 正常系・認可・種苗法対応バリデーション。"""

import httpx
import psycopg
import pytest

from tests.conftest import TEST_DSN, auth


def base_body(**over: object) -> dict[str, object]:
    body: dict[str, object] = {
        "variety_name_free": "みやま小かぶ",
        "category_id": 3,
        "title": "みやま小かぶの種(自家採種)",
        "listing_type": "exchange",
        "desired_trade": "在来種の葉物",
        "is_self_saved": True,
        "non_registered_confirmed": True,
    }
    body.update(over)
    return body


def insert_variety(**over: object) -> str:
    cols: dict[str, object] = {
        "name": "登録品種X",
        "category_id": 1,
        "status": "approved",
        "is_registered_variety": False,
    }
    cols.update(over)
    with psycopg.connect(TEST_DSN, autocommit=True) as conn:
        row = conn.execute(
            "INSERT INTO shared.varieties"
            " (name, category_id, status, is_registered_variety)"
            " VALUES (%(name)s, %(category_id)s, %(status)s,"
            " %(is_registered_variety)s) RETURNING id",
            cols,
        ).fetchone()
    assert row is not None
    return str(row[0])


@pytest.mark.anyio
async def test_create_and_get(client: httpx.AsyncClient) -> None:
    res = await client.post("/api/v1/listings", json=base_body(), headers=auth())
    assert res.status_code == 201, res.text
    created = res.json()
    # 個人の家庭採種品は既定で無保証表示
    assert created["no_warranty"] is True
    # 自由入力 → pending 提案が自動生成され紐付く
    assert created["variety_id"] is not None

    res = await client.get(f"/api/v1/listings/{created['id']}")
    assert res.status_code == 200
    assert res.json()["title"] == created["title"]

    with psycopg.connect(TEST_DSN) as conn:
        status = conn.execute(
            "SELECT status FROM shared.varieties WHERE name = 'みやま小かぶ'"
        ).fetchone()
    assert status == ("pending",)


@pytest.mark.anyio
async def test_confirmation_required(client: httpx.AsyncClient) -> None:
    body = base_body(non_registered_confirmed=False)
    res = await client.post("/api/v1/listings", json=body, headers=auth())
    assert res.status_code == 422
    assert res.json()["code"] == "CONFIRMATION_REQUIRED"


@pytest.mark.anyio
async def test_registered_variety_blocked(client: httpx.AsyncClient) -> None:
    vid = insert_variety(name="とちおとめ", is_registered_variety=True)
    body = base_body(variety_id=vid, variety_name_free=None)
    res = await client.post("/api/v1/listings", json=body, headers=auth())
    assert res.status_code == 409
    assert res.json()["code"] == "REGISTERED_VARIETY"


@pytest.mark.anyio
async def test_registered_variety_blocked_by_free_name(
    client: httpx.AsyncClient,
) -> None:
    # 自由入力でも既存の登録品種名と一致したらブロック(緩和禁止)
    insert_variety(name="とちおとめ", is_registered_variety=True)
    body = base_body(variety_name_free="とちおとめ")
    res = await client.post("/api/v1/listings", json=body, headers=auth())
    assert res.status_code == 409
    assert res.json()["code"] == "REGISTERED_VARIETY"


@pytest.mark.anyio
async def test_variety_required(client: httpx.AsyncClient) -> None:
    body = base_body(variety_name_free=None)
    res = await client.post("/api/v1/listings", json=body, headers=auth())
    assert res.status_code == 422
    assert res.json()["code"] == "VARIETY_REQUIRED"


@pytest.mark.anyio
async def test_seed_label_required(client: httpx.AsyncClient) -> None:
    body = base_body(
        requires_seed_label=True,
        label_seller_name="種苗店",
        label_seller_address="埼玉県…",
        # label_production_area・label_germination_rate 不足
    )
    res = await client.post("/api/v1/listings", json=body, headers=auth())
    assert res.status_code == 422
    assert res.json()["code"] == "SEED_LABEL_REQUIRED"


@pytest.mark.anyio
async def test_seed_label_complete_and_no_warranty_off(
    client: httpx.AsyncClient,
) -> None:
    body = base_body(
        listing_type="sell",
        price_yen=360,
        requires_seed_label=True,
        label_seller_name="たねの森",
        label_seller_address="埼玉県日高市…",
        label_production_area="埼玉県",
        label_germination_rate="2026年6月現在 80%以上",
    )
    res = await client.post("/api/v1/listings", json=body, headers=auth())
    assert res.status_code == 201, res.text
    created = res.json()
    # 業者品(指定種苗表示あり)は無保証表示にならない
    assert created["no_warranty"] is False
    assert created["label_germination_rate"] == "2026年6月現在 80%以上"


@pytest.mark.anyio
async def test_sell_requires_price(client: httpx.AsyncClient) -> None:
    body = base_body(listing_type="sell")
    res = await client.post("/api/v1/listings", json=body, headers=auth())
    assert res.status_code == 422
    assert res.json()["code"] == "PRICE_REQUIRED"


@pytest.mark.anyio
async def test_list_filters(client: httpx.AsyncClient) -> None:
    await client.post("/api/v1/listings", json=base_body(), headers=auth())
    await client.post(
        "/api/v1/listings",
        json=base_body(
            variety_name_free="真黒茄子",
            category_id=1,
            title="真黒茄子の種",
            listing_type="give",
            desired_trade=None,
        ),
        headers=auth(),
    )
    res = await client.get("/api/v1/listings")
    assert len(res.json()["items"]) == 2

    res = await client.get("/api/v1/listings", params={"category": "fruit-veg"})
    items = res.json()["items"]
    assert len(items) == 1
    assert items[0]["title"] == "真黒茄子の種"

    res = await client.get("/api/v1/listings", params={"type": "exchange"})
    assert len(res.json()["items"]) == 1

    res = await client.get("/api/v1/listings", params={"q": "小かぶ"})
    assert len(res.json()["items"]) == 1
