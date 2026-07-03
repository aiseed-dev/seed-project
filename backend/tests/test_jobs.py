# SPDX-License-Identifier: AGPL-3.0-only
"""定期ジョブ: 期限切れ自動クローズと未読通知。"""

import datetime

import httpx
import psycopg
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

import app.services.mail as mail_module
from app.services import jobs
from tests.conftest import TEST_DSN, auth
from tests.test_requests import carted_request


@pytest.fixture
def sent(monkeypatch: pytest.MonkeyPatch) -> list[tuple[str, str]]:
    calls: list[tuple[str, str]] = []
    monkeypatch.setattr(
        mail_module, "send_to_user", lambda u, s, b: calls.append((u, s)) or True
    )
    return calls


@pytest.fixture
def db() -> Session:
    engine = create_engine(TEST_DSN.replace("postgresql://", "postgresql+psycopg://"))
    with Session(engine) as session:
        yield session
    engine.dispose()


@pytest.mark.anyio
async def test_expire_requests(
    client: httpx.AsyncClient, sent: list[tuple[str, str]], db: Session
) -> None:
    fresh = await carted_request(client)
    stale = await carted_request(client, provider="prov2", buyer="buyer2")
    with psycopg.connect(TEST_DSN, autocommit=True) as conn:
        conn.execute(
            "UPDATE exchange.requests SET created_at = now() - interval '8 days'"
            " WHERE id = %s",
            (stale["id"],),
        )

    sent.clear()  # 申込み作成時の即時メールを除く
    count = jobs.expire_requests(db)
    assert count == 1

    res = await client.get(f"/api/v1/requests/{stale['id']}", headers=auth("buyer2"))
    assert res.json()["status"] == "expired"
    res = await client.get(f"/api/v1/requests/{fresh['id']}", headers=auth("buyer"))
    assert res.json()["status"] == "requested"
    # 申込者・提供者の双方に通知
    assert {u for u, _ in sent} == {"buyer2", "prov2"}


@pytest.mark.anyio
async def test_notify_unread_once_per_request(
    client: httpx.AsyncClient, sent: list[tuple[str, str]], db: Session
) -> None:
    req = await carted_request(client)
    for body in ["こんにちは", "送料の件です"]:
        await client.post(
            f"/api/v1/requests/{req['id']}/messages",
            json={"body": body},
            headers=auth("prov1"),
        )
    with psycopg.connect(TEST_DSN, autocommit=True) as conn:
        conn.execute(
            "UPDATE exchange.messages"
            " SET sent_at = now() - interval '15 minutes 30 seconds'"
        )

    now = datetime.datetime.now(datetime.UTC)
    count = jobs.notify_unread(db, now=now)
    assert count == 1  # 申込みごとに1通(2通のメッセージでも)
    assert sent[-1][0] == "buyer"

    # 次の実行ウィンドウ(1分後)では再送しない
    count = jobs.notify_unread(db, now=now + datetime.timedelta(minutes=1))
    assert count == 0
