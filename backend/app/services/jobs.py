# SPDX-License-Identifier: AGPL-3.0-only
"""定期ジョブ(docs/03)。cron 等から scripts/jobs.py 経由で毎分実行する。

- 申込みの期限切れ: requested のまま既定7日でexpired に自動クローズし、
  申込者・提供者にメール通知
- メッセージ未読15分の通知: 15分の閾値を「前回実行以降に」超えたものに
  1通送る(申込みごとにまとめる。実行間隔=1分を前提とした近似)
"""

import datetime
import logging

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models import Message, Request, ShopMember
from app.services import mail

logger = logging.getLogger(__name__)

UNREAD_MINUTES = 15


def _provider_user_ids(db: Session, request: Request) -> list[str]:
    if request.provider_user_id is not None:
        return [request.provider_user_id]
    return list(
        db.scalars(
            select(ShopMember.user_id).where(
                ShopMember.shop_id == request.provider_shop_id
            )
        ).all()
    )


def expire_requests(db: Session, now: datetime.datetime | None = None) -> int:
    """requested のまま放置された申込みを expired にする。件数を返す。"""
    now = now or datetime.datetime.now(datetime.UTC)
    limit = now - datetime.timedelta(days=settings().request_expire_days)
    stale = db.scalars(
        select(Request).where(Request.status == "requested", Request.created_at < limit)
    ).all()
    for request in stale:
        request.status = "expired"
        subject = f"[種の交換] 申込みが期限切れになりました({request.request_no})"
        body = "一定期間ご対応がなかったため自動的にクローズしました。"
        mail.send_to_user(request.requester_id, subject, body)
        for user_id in _provider_user_ids(db, request):
            mail.send_to_user(user_id, subject, body)
    db.commit()
    return len(stale)


def notify_unread(
    db: Session,
    now: datetime.datetime | None = None,
    interval: datetime.timedelta = datetime.timedelta(minutes=1),
) -> int:
    """未読15分を超えたメッセージを申込みごとに1通通知する。"""
    now = now or datetime.datetime.now(datetime.UTC)
    threshold = now - datetime.timedelta(minutes=UNREAD_MINUTES)
    window_start = threshold - interval  # 前回実行以降に閾値を超えた分
    rows = db.execute(
        select(Message, Request)
        .join(Request, Message.request_id == Request.id)
        .where(
            Message.read_at.is_(None),
            Message.sent_at < threshold,
            Message.sent_at >= window_start,
        )
        .order_by(Message.sent_at)
    ).all()
    notified: set[tuple[str, str]] = set()  # (request_id, 受信者)
    for message, request in rows:
        recipients = (
            [request.requester_id]
            if message.sender_id != request.requester_id
            else _provider_user_ids(db, request)
        )
        for user_id in recipients:
            key = (str(request.id), user_id)
            if key in notified:
                continue
            notified.add(key)
            preview = message.body[:40]
            mail.send_to_user(
                user_id,
                f"[種の交換] 未読メッセージがあります({request.request_no})",
                f"{preview}\nアプリで確認してください。",
            )
    return len(notified)
