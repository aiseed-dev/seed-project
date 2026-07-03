# SPDX-License-Identifier: AGPL-3.0-only
import httpx
import psycopg
import pytest

from tests.conftest import TEST_DSN, auth
from tests.test_listings import base_body


async def make_listing(client: httpx.AsyncClient, owner: str, **over: object) -> dict:
    res = await client.post(
        "/api/v1/listings", json=base_body(**over), headers=auth(owner)
    )
    assert res.status_code == 201, res.text
    return res.json()


@pytest.mark.anyio
async def test_cart_grouped_by_provider(client: httpx.AsyncClient) -> None:
    a = await make_listing(client, "prov1")
    b = await make_listing(
        client,
        "prov1",
        variety_name_free="真黒茄子",
        title="真黒茄子の種",
        listing_type="sell",
        price_yen=360,
        desired_trade=None,
    )
    c = await make_listing(
        client, "prov2", variety_name_free="山東菜", title="山東菜の種"
    )

    for listing, qty in [(a, 1), (b, 3), (c, 1)]:
        res = await client.put(
            f"/api/v1/cart/items/{listing['id']}",
            json={"quantity": qty},
            headers=auth("buyer"),
        )
        assert res.status_code == 200, res.text

    res = await client.get("/api/v1/cart", headers=auth("buyer"))
    groups = res.json()
    assert len(groups) == 2
    by_provider = {g["provider"]["id"]: g for g in groups}
    g1 = by_provider["prov1"]
    assert len(g1["items"]) == 2
    assert g1["subtotal_yen"] == 360 * 3  # 販売品のみの小計(送料別)
    assert by_provider["prov2"]["subtotal_yen"] is None  # 交換のみは小計なし


@pytest.mark.anyio
async def test_cart_rejects_closed_listing(client: httpx.AsyncClient) -> None:
    listing = await make_listing(client, "prov1")
    with psycopg.connect(TEST_DSN, autocommit=True) as conn:
        conn.execute(
            "UPDATE exchange.listings SET status = 'closed' WHERE id = %s",
            (listing["id"],),
        )
    res = await client.put(
        f"/api/v1/cart/items/{listing['id']}",
        json={"quantity": 1},
        headers=auth("buyer"),
    )
    assert res.status_code == 409
    assert res.json()["code"] == "NOT_AVAILABLE"


@pytest.mark.anyio
async def test_cart_delete(client: httpx.AsyncClient) -> None:
    listing = await make_listing(client, "prov1")
    await client.put(
        f"/api/v1/cart/items/{listing['id']}",
        json={"quantity": 1},
        headers=auth("buyer"),
    )
    res = await client.delete(
        f"/api/v1/cart/items/{listing['id']}", headers=auth("buyer")
    )
    assert res.status_code == 204
    res = await client.get("/api/v1/cart", headers=auth("buyer"))
    assert res.json() == []
