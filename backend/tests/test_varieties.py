# SPDX-License-Identifier: AGPL-3.0-only
import httpx
import pytest

from tests.conftest import auth
from tests.test_listings import insert_variety


@pytest.mark.anyio
async def test_search_by_partial_name(client: httpx.AsyncClient) -> None:
    insert_variety(name="三浦大根", status="approved")
    insert_variety(name="聖護院大根", status="approved")
    insert_variety(name="真黒茄子", status="approved")
    res = await client.get("/api/v1/varieties", params={"q": "大根"})
    names = [v["name"] for v in res.json()]
    assert set(names) == {"三浦大根", "聖護院大根"}


@pytest.mark.anyio
async def test_search_excludes_pending(client: httpx.AsyncClient) -> None:
    insert_variety(name="提案中の大根", status="pending")
    res = await client.get("/api/v1/varieties", params={"q": "大根"})
    assert res.json() == []


@pytest.mark.anyio
async def test_pending_proposal_not_searchable_after_post(
    client: httpx.AsyncClient,
) -> None:
    from tests.test_listings import base_body

    await client.post("/api/v1/listings", json=base_body(), headers=auth())
    res = await client.get("/api/v1/varieties", params={"q": "みやま小かぶ"})
    assert res.json() == []  # 承認されるまで検索に出ない


@pytest.mark.anyio
async def test_get_variety(client: httpx.AsyncClient) -> None:
    vid = insert_variety(name="のらぼう菜", status="approved")
    res = await client.get(f"/api/v1/varieties/{vid}")
    assert res.status_code == 200
    assert res.json()["name"] == "のらぼう菜"
