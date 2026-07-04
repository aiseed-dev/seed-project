# SPDX-License-Identifier: AGPL-3.0-only
"""admin から使う業務ロジック(品種承認・却下・通報対応)。"""

import httpx
import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from app.models import Listing, Variety
from app.services.variety import approve_variety, reject_variety
from tests.conftest import TEST_DSN, auth
from tests.test_listings import base_body


@pytest.fixture
def db() -> Session:
    import psycopg

    with psycopg.connect(TEST_DSN, autocommit=True) as conn:
        conn.execute(
            "INSERT INTO shared.app_users (id, display_name, role)"
            " VALUES ('admin1', '運営', 'admin') ON CONFLICT (id) DO NOTHING"
        )
    engine = create_engine(TEST_DSN.replace("postgresql://", "postgresql+psycopg://"))
    with Session(engine) as session:
        yield session
    engine.dispose()


@pytest.mark.anyio
async def test_approve_creates_article_shell(
    client: httpx.AsyncClient, db: Session
) -> None:
    # 出品の自由入力 → pending 提案
    await client.post("/api/v1/listings", json=base_body(), headers=auth("u1"))
    variety = db.scalars(select(Variety).where(Variety.name == "みやま小かぶ")).one()
    approve_variety(db, variety, "admin1", kana="みやまこかぶ", seed_type="fixed")
    db.commit()

    # 検索に出るようになり、記事枠もできている
    res = await client.get("/api/v1/varieties", params={"q": "小かぶ"})
    assert [v["name"] for v in res.json()] == ["みやま小かぶ"]
    res = await client.get(f"/api/v1/articles/{variety.id}")
    assert res.status_code == 200


@pytest.mark.anyio
async def test_reject_registered_flags_listings(
    client: httpx.AsyncClient, db: Session
) -> None:
    created = await client.post(
        "/api/v1/listings",
        json=base_body(variety_name_free="とちおとめ", title="いちごの苗"),
        headers=auth("u1"),
    )
    listing_id = created.json()["id"]
    variety = db.scalars(select(Variety).where(Variety.name == "とちおとめ")).one()
    flagged = reject_variety(
        db, variety, "admin1", is_registered=True, note="品種登録DBで確認"
    )
    db.commit()
    assert flagged == 1
    assert db.get(Listing, listing_id).moderation == "flagged"

    # flagged の出品は公開一覧から消える
    res = await client.get("/api/v1/listings")
    assert res.json()["items"] == []

    # 以後、同名の自由入力での出品はブロックされる
    res = await client.post(
        "/api/v1/listings",
        json=base_body(variety_name_free="とちおとめ", title="再出品"),
        headers=auth("u2"),
    )
    assert res.status_code == 409
    assert res.json()["code"] == "REGISTERED_VARIETY"
