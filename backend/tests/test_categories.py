# SPDX-License-Identifier: AGPL-3.0-only
import httpx
import pytest


@pytest.mark.anyio
async def test_list_categories(client: httpx.AsyncClient) -> None:
    res = await client.get("/api/v1/categories")
    assert res.status_code == 200
    rows = res.json()
    assert len(rows) == 8
    assert rows[0] == {
        "id": 1,
        "slug": "fruit-veg",
        "name": "果菜",
        "icon": None,
        "sort_order": 1,
    }
