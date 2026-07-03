# SPDX-License-Identifier: AGPL-3.0-only
"""Phase 5a/5b: QR・カタログJSON・生産物の表示義務。"""

import datetime
import json

import httpx
import pytest

from tests.conftest import auth
from tests.test_listings import base_body
from tests.test_shop import make_shop


@pytest.mark.anyio
async def test_qr_png(client: httpx.AsyncClient) -> None:
    res = await client.get("/api/v1/qr/v/some-variety-id.png")
    assert res.status_code == 200
    assert res.headers["content-type"] == "image/png"
    assert res.content[:8] == b"\x89PNG\r\n\x1a\n"

    res = await client.get("/api/v1/qr/x/oops.png")
    assert res.status_code == 404


@pytest.mark.anyio
async def test_produce_mail_requires_food_label(client: httpx.AsyncClient) -> None:
    body = base_body(item_kind="produce", delivery_method="mail")
    res = await client.post("/api/v1/listings", json=body, headers=auth())
    assert res.status_code == 422
    assert res.json()["code"] == "FOOD_LABEL_REQUIRED"

    body = base_body(
        item_kind="produce",
        delivery_method="mail",
        food_name="だいこん",
        food_origin="徳島県",
        food_producer="種子 太郎",
        food_harvest_date=str(datetime.date(2026, 7, 1)),
        food_storage="冷暗所",
    )
    res = await client.post("/api/v1/listings", json=body, headers=auth())
    assert res.status_code == 201, res.text
    assert res.json()["food_name"] == "だいこん"

    # 直接受け渡しなら食品表示は不要
    body = base_body(item_kind="produce", delivery_method="direct")
    res = await client.post("/api/v1/listings", json=body, headers=auth())
    assert res.status_code == 201


@pytest.mark.anyio
async def test_tokushoho_requires_shop_profile(client: httpx.AsyncClient) -> None:
    body = base_body(requires_tokushoho=True)
    res = await client.post("/api/v1/listings", json=body, headers=auth())
    assert res.status_code == 422
    assert res.json()["code"] == "TOKUSHOHO_REQUIRED"

    # 店舗プロフィールが揃っていれば通る
    make_shop(owner="staff1")
    await client.patch(
        "/api/v1/shop",
        json={
            "contact_phone": "042-982-5023",
            "return_policy": "未開封のみ7日以内",
            "delivery_time": "入金確認後5日以内",
        },
        headers=auth("staff1"),
    )
    res = await client.post(
        "/api/v1/listings",
        json=base_body(requires_tokushoho=True),
        headers=auth("staff1"),
    )
    assert res.status_code == 201, res.text


@pytest.mark.anyio
async def test_catalog_json(client: httpx.AsyncClient, tmp_path) -> None:
    from tests.test_listings import insert_variety

    insert_variety(name="のらぼう菜", status="approved")
    from scripts.catalogjson import build

    counts = build(tmp_path)
    assert counts["categories"] == 8
    assert counts["varieties"] == 1
    data = json.loads((tmp_path / "varieties.json").read_text(encoding="utf-8"))
    assert data[0]["name"] == "のらぼう菜"
