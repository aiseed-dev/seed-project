# SPDX-License-Identifier: AGPL-3.0-only
"""メール送信の集約(docs/03)。

- 送信は localhost の Stalwart へ SMTP。環境変数で外部リレーに切替できる
- 宛先メールアドレスは PocketBase から引く(業務DBには保持しない方針)
- 失敗しても業務処理は止めない(ログのみ)
"""

import logging
import smtplib
from email.message import EmailMessage

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


def _lookup_email(user_id: str) -> str | None:
    """PocketBase からユーザーのメールアドレスを引く(管理トークン使用)。"""
    conf = settings()
    if not conf.pocketbase_admin_token:
        return None
    try:
        res = httpx.get(
            f"{conf.pocketbase_url}/api/collections/users/records/{user_id}",
            headers={"Authorization": f"Bearer {conf.pocketbase_admin_token}"},
            timeout=5,
        )
    except httpx.HTTPError:
        return None
    if res.status_code != 200:
        return None
    return res.json().get("email")


def send_to_user(user_id: str, subject: str, body: str) -> bool:
    """ユーザー宛にメールを送る。送れたら True(失敗は握って False)。"""
    email = _lookup_email(user_id)
    if not email:
        logger.info("メール送信スキップ(宛先不明): %s %s", user_id, subject)
        return False
    conf = settings()
    message = EmailMessage()
    message["From"] = conf.mail_from
    message["To"] = email
    message["Subject"] = subject
    message.set_content(body)
    try:
        with smtplib.SMTP(conf.smtp_host, conf.smtp_port, timeout=10) as smtp:
            if conf.smtp_user:  # 外部リレー利用時のみ認証
                smtp.starttls()
                smtp.login(conf.smtp_user, conf.smtp_password)
            smtp.send_message(message)
    except OSError as e:
        logger.warning("メール送信失敗: %s (%s)", subject, e)
        return False
    return True
