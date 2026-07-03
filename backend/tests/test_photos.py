# SPDX-License-Identifier: AGPL-3.0-only
import io

import httpx
import pytest
from PIL import Image

from tests.conftest import auth
from tests.test_listings import base_body


def png(width: int, height: int) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (width, height), "green").save(buf, format="PNG")
    return buf.getvalue()


async def create_listing(client: httpx.AsyncClient) -> str:
    res = await client.post("/api/v1/listings", json=base_body(), headers=auth())
    assert res.status_code == 201
    return str(res.json()["id"])


@pytest.mark.anyio
async def test_upload_resizes_to_1600(client: httpx.AsyncClient) -> None:
    from app.core.config import settings

    listing_id = await create_listing(client)
    res = await client.post(
        f"/api/v1/listings/{listing_id}/photos",
        files={"files": ("large.png", png(3200, 1600), "image/png")},
        headers=auth(),
    )
    assert res.status_code == 201, res.text
    path = settings().images_dir / res.json()[0]["path"]
    with Image.open(path) as saved:
        assert max(saved.size) == 1600


@pytest.mark.anyio
async def test_upload_rejects_non_image(client: httpx.AsyncClient) -> None:
    listing_id = await create_listing(client)
    res = await client.post(
        f"/api/v1/listings/{listing_id}/photos",
        files={"files": ("evil.txt", b"not an image", "text/plain")},
        headers=auth(),
    )
    assert res.status_code == 422
    assert res.json()["code"] == "PHOTO_FORMAT"


@pytest.mark.anyio
async def test_photo_limit_4(client: httpx.AsyncClient) -> None:
    listing_id = await create_listing(client)
    image = png(100, 100)
    files = [("files", (f"p{i}.png", image, "image/png")) for i in range(4)]
    res = await client.post(
        f"/api/v1/listings/{listing_id}/photos", files=files, headers=auth()
    )
    assert res.status_code == 201
    res = await client.post(
        f"/api/v1/listings/{listing_id}/photos",
        files={"files": ("p5.png", image, "image/png")},
        headers=auth(),
    )
    assert res.status_code == 422
    assert res.json()["code"] == "PHOTO_LIMIT"


@pytest.mark.anyio
async def test_photo_owner_only(client: httpx.AsyncClient) -> None:
    listing_id = await create_listing(client)
    res = await client.post(
        f"/api/v1/listings/{listing_id}/photos",
        files={"files": ("p.png", png(100, 100), "image/png")},
        headers=auth("someone-else"),
    )
    assert res.status_code == 403
    assert res.json()["code"] == "NOT_OWNER"

    res = await client.post(
        f"/api/v1/listings/{listing_id}/photos",
        files={"files": ("p.png", png(100, 100), "image/png")},
        headers=auth(),
    )
    photo_id = res.json()[0]["id"]
    res = await client.delete(
        f"/api/v1/photos/{photo_id}", headers=auth("someone-else")
    )
    assert res.status_code == 403
    res = await client.delete(f"/api/v1/photos/{photo_id}", headers=auth())
    assert res.status_code == 204
