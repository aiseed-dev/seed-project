# SPDX-License-Identifier: AGPL-3.0-only
"""申込みフロー: 採番・状態遷移・メッセージ・評価・通報。"""

import httpx
import pytest

import app.services.mail as mail_module
from tests.conftest import auth
from tests.test_cart import make_listing


@pytest.fixture
def sent(monkeypatch: pytest.MonkeyPatch) -> list[tuple[str, str]]:
    calls: list[tuple[str, str]] = []

    def spy(user_id: str, subject: str, body: str) -> bool:
        calls.append((user_id, subject))
        return True

    monkeypatch.setattr(mail_module, "send_to_user", spy)
    return calls


async def carted_request(
    client: httpx.AsyncClient, provider: str = "prov1", buyer: str = "buyer"
) -> dict:
    listing = await make_listing(client, provider)
    await client.put(
        f"/api/v1/cart/items/{listing['id']}",
        json={"quantity": 2},
        headers=auth(buyer),
    )
    res = await client.post(
        "/api/v1/requests",
        json={"provider_kind": "user", "provider_id": provider, "note": "よろしく"},
        headers=auth(buyer),
    )
    assert res.status_code == 201, res.text
    return res.json()


@pytest.mark.anyio
async def test_request_numbering_and_cart_move(
    client: httpx.AsyncClient, sent: list[tuple[str, str]]
) -> None:
    first = await carted_request(client)
    assert first["request_no"].endswith("-00001")
    assert len(first["items"]) == 1
    assert first["items"][0]["quantity"] == 2

    # カートは空になる
    res = await client.get("/api/v1/cart", headers=auth("buyer"))
    assert res.json() == []

    # 通し番号は提供者をまたいで一連(店舗・個人を区別しない)
    second = await carted_request(client, provider="prov2", buyer="buyer2")
    assert second["request_no"].endswith("-00002")

    # 提供者に即時メール
    assert any(u == "prov1" and "届きました" in s for u, s in sent)


@pytest.mark.anyio
async def test_empty_cart_for_provider(client: httpx.AsyncClient) -> None:
    res = await client.post(
        "/api/v1/requests",
        json={"provider_kind": "user", "provider_id": "nobody"},
        headers=auth("buyer"),
    )
    assert res.status_code == 422
    assert res.json()["code"] == "CART_EMPTY"


@pytest.mark.anyio
async def test_accept_complete_and_review(
    client: httpx.AsyncClient, sent: list[tuple[str, str]]
) -> None:
    req = await carted_request(client)
    rid = req["id"]

    # 第三者には見えない
    res = await client.get(f"/api/v1/requests/{rid}", headers=auth("stranger"))
    assert res.status_code == 404

    # 申込者は承諾できない
    res = await client.patch(
        f"/api/v1/requests/{rid}", json={"status": "accepted"}, headers=auth("buyer")
    )
    assert res.status_code == 409

    # 提供者が承諾 → accepted_at / accepted_by が記録される
    res = await client.patch(
        f"/api/v1/requests/{rid}", json={"status": "accepted"}, headers=auth("prov1")
    )
    assert res.status_code == 200
    assert res.json()["accepted_at"] is not None
    assert any(u == "buyer" and "承諾" in s for u, s in sent)

    # 完了(どちらからでも)→ completed_at 記録
    res = await client.patch(
        f"/api/v1/requests/{rid}", json={"status": "completed"}, headers=auth("buyer")
    )
    assert res.json()["completed_at"] is not None

    # 相互評価。二重評価は 409
    res = await client.post(
        f"/api/v1/requests/{rid}/reviews",
        json={"score": 5, "comment": "ありがとう"},
        headers=auth("buyer"),
    )
    assert res.status_code == 201
    assert res.json()["reviewee_id"] == "prov1"
    res = await client.post(
        f"/api/v1/requests/{rid}/reviews", json={"score": 4}, headers=auth("prov1")
    )
    assert res.status_code == 201
    assert res.json()["reviewee_id"] == "buyer"
    res = await client.post(
        f"/api/v1/requests/{rid}/reviews", json={"score": 1}, headers=auth("buyer")
    )
    assert res.status_code == 409
    assert res.json()["code"] == "DUPLICATE_REVIEW"


@pytest.mark.anyio
async def test_decline_and_cancel(
    client: httpx.AsyncClient, sent: list[tuple[str, str]]
) -> None:
    req = await carted_request(client)
    res = await client.patch(
        f"/api/v1/requests/{req['id']}",
        json={"status": "declined"},
        headers=auth("prov1"),
    )
    assert res.status_code == 200
    # 完了へは進めない
    res = await client.patch(
        f"/api/v1/requests/{req['id']}",
        json={"status": "completed"},
        headers=auth("buyer"),
    )
    assert res.status_code == 409

    req2 = await carted_request(client, provider="prov2", buyer="buyer2")
    res = await client.patch(
        f"/api/v1/requests/{req2['id']}",
        json={"status": "cancelled"},
        headers=auth("buyer2"),
    )
    assert res.status_code == 200


@pytest.mark.anyio
async def test_messages_and_read(client: httpx.AsyncClient) -> None:
    req = await carted_request(client)
    rid = req["id"]
    res = await client.post(
        f"/api/v1/requests/{rid}/messages",
        json={"body": "送料は120円です"},
        headers=auth("prov1"),
    )
    assert res.status_code == 201

    # 相手が開くと既読になる
    res = await client.get(f"/api/v1/requests/{rid}/messages", headers=auth("buyer"))
    messages = res.json()
    assert len(messages) == 1
    assert messages[0]["read_at"] is not None

    # 一覧に最終メッセージが載る
    res = await client.get("/api/v1/requests", headers=auth("buyer"))
    entry = res.json()[0]
    assert entry["last_message"] == "送料は120円です"
    assert entry["role"] == "requester"


@pytest.mark.anyio
async def test_report(client: httpx.AsyncClient) -> None:
    listing = await make_listing(client, "prov1")
    res = await client.post(
        "/api/v1/reports",
        json={
            "target_type": "listing",
            "target_id": listing["id"],
            "reason": "registered_variety",
            "detail": "登録品種の疑い",
        },
        headers=auth("buyer"),
    )
    assert res.status_code == 201
    assert res.json()["status"] == "open"
