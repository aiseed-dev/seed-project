# SPDX-License-Identifier: AGPL-3.0-only
"""辞典: 提案受付・editor 承認(difflib差分)・エクスポート。"""

import httpx
import psycopg
import pytest

from tests.conftest import TEST_DSN, auth
from tests.test_listings import insert_variety

CONTENT1 = {"history": "江戸時代から続く。", "cultivation": "春まき。"}
CONTENT2 = {
    "history": "江戸時代から続く。\n明治に広まった。",
    "cultivation": "春まき。",
}


def make_editor(user_id: str = "ed1") -> None:
    with psycopg.connect(TEST_DSN, autocommit=True) as conn:
        conn.execute(
            "INSERT INTO shared.app_users (id, display_name, role)"
            " VALUES (%s, %s, 'editor')"
            " ON CONFLICT (id) DO UPDATE SET role = 'editor'",
            (user_id, f"編集者{user_id}"),
        )


@pytest.mark.anyio
async def test_revision_flow(client: httpx.AsyncClient) -> None:
    vid = insert_variety(name="のらぼう菜", status="approved")
    make_editor()

    # 記事はまだ準備中(空)
    res = await client.get(f"/api/v1/articles/{vid}")
    assert res.status_code == 200
    assert res.json()["content"] == {}

    # 提案(記事枠は自動作成)
    res = await client.post(
        f"/api/v1/articles/{vid}/revisions",
        json={"content": CONTENT1, "edit_summary": "初版"},
        headers=auth("author"),
    )
    assert res.status_code == 201, res.text
    rev1 = res.json()
    assert rev1["status"] == "pending"

    # editor 以外は 403
    res = await client.get("/api/v1/editor/revisions", headers=auth("author"))
    assert res.status_code == 403
    assert res.json()["code"] == "NOT_EDITOR"

    # キュー → 承認 → 公開される
    res = await client.get("/api/v1/editor/revisions", headers=auth("ed1"))
    queue = res.json()
    assert len(queue) == 1
    assert queue[0]["variety_name"] == "のらぼう菜"

    res = await client.patch(
        f"/api/v1/editor/revisions/{rev1['id']}",
        json={"action": "approve"},
        headers=auth("ed1"),
    )
    assert res.status_code == 200
    res = await client.get(f"/api/v1/articles/{vid}")
    assert res.json()["content"] == CONTENT1

    # 2版目の提案 → 差分がサーバー側で計算される
    res = await client.post(
        f"/api/v1/articles/{vid}/revisions",
        json={"content": CONTENT2, "edit_summary": "明治の来歴を追記"},
        headers=auth("author"),
    )
    rev2 = res.json()
    res = await client.get(
        f"/api/v1/editor/revisions/{rev2['id']}", headers=auth("ed1")
    )
    diff = res.json()["diff"]
    history_ops = [(line["op"], line["text"]) for line in diff["history"]]
    assert ("keep", "江戸時代から続く。") in history_ops
    assert ("add", "明治に広まった。") in history_ops

    # 却下には理由が必須
    res = await client.patch(
        f"/api/v1/editor/revisions/{rev2['id']}",
        json={"action": "reject"},
        headers=auth("ed1"),
    )
    assert res.status_code == 422
    res = await client.patch(
        f"/api/v1/editor/revisions/{rev2['id']}",
        json={"action": "reject", "review_note": "出典を追記してください"},
        headers=auth("ed1"),
    )
    assert res.status_code == 200

    # 著者は自分の提案と状態を見られる
    res = await client.get("/api/v1/me/revisions", headers=auth("author"))
    statuses = {r["status"] for r in res.json()}
    assert statuses == {"approved", "rejected"}

    # エクスポート(認証不要)
    res = await client.get("/api/v1/articles/export")
    assert res.status_code == 200
    assert res.json()[0]["variety_name"] == "のらぼう菜"
    assert res.json()[0]["content"] == CONTENT1


@pytest.mark.anyio
async def test_unknown_section_rejected(client: httpx.AsyncClient) -> None:
    vid = insert_variety(name="真黒茄子", status="approved")
    res = await client.post(
        f"/api/v1/articles/{vid}/revisions",
        json={"content": {"hack": "x"}},
        headers=auth("author"),
    )
    assert res.status_code == 422
    assert res.json()["code"] == "SECTION_INVALID"


@pytest.mark.anyio
async def test_propose_variety_and_me(client: httpx.AsyncClient) -> None:
    res = await client.post(
        "/api/v1/varieties",
        json={"name": "祝だいこん", "category_id": 3, "kana": "いわいだいこん"},
        headers=auth("u1"),
    )
    assert res.status_code == 201
    assert res.json()["status"] == "pending"

    res = await client.get("/api/v1/me", headers=auth("u1"))
    assert res.json()["role"] == "user"
    res = await client.patch(
        "/api/v1/me", json={"region": "徳島県"}, headers=auth("u1")
    )
    assert res.json()["region"] == "徳島県"
