# SPDX-License-Identifier: AGPL-3.0-only
"""通報対応(事後審査)。admin アプリ(DB直結)から使う。"""

from sqlalchemy.orm import Session

from app.models import AppUser, Listing, Report
from app.services import mail


def flag_listing(db: Session, listing: Listing, *, removed: bool, note: str) -> None:
    """出品を停止(flagged)または削除(removed)し、出品者へ通知する。"""
    listing.moderation = "removed" if removed else "flagged"
    db.flush()
    label = "削除" if removed else "一時停止"
    mail.send_to_user(
        listing.user_id,
        f"[種の交換] 出品を{label}しました",
        f"理由: {note}\nお心当たりがない場合は運営までご連絡ください。",
    )


def suspend_user(db: Session, user: AppUser, *, note: str) -> None:
    """ユーザーを凍結する(以後の認証必須操作は 403 SUSPENDED)。"""
    user.is_suspended = True
    db.flush()
    mail.send_to_user(
        user.id,
        "[種の交換] アカウントを停止しました",
        f"理由: {note}\n異議がある場合は運営までご連絡ください。",
    )


def close_report(
    db: Session, report: Report, handler_id: str, *, dismissed: bool
) -> None:
    """通報を resolved / dismissed にする。"""
    report.status = "dismissed" if dismissed else "resolved"
    report.handled_by = handler_id
    db.flush()
