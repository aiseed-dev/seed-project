# SPDX-License-Identifier: AGPL-3.0-only
"""品種提案(出品画面の自由入力から品種マスタへの pending 提案)。

登録品種チェックの緩和・スキップは禁止(CLAUDE.md)。
"""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.models import Variety


def resolve_free_name(
    db: Session, name: str, category_id: int, user_id: str
) -> Variety:
    """自由入力の品種名を品種マスタに解決する。

    - 同名の品種が既にあればそれを使う(登録品種なら 409)
    - 無ければ status='pending' の提案を自動生成する
    """
    name = name.strip()
    existing = db.scalars(select(Variety).where(Variety.name == name).limit(1)).first()
    if existing is not None:
        if existing.is_registered_variety:
            raise ApiError(
                409,
                "REGISTERED_VARIETY",
                f"「{name}」は登録品種のため出品できません",
            )
        return existing
    variety = Variety(
        name=name,
        category_id=category_id,
        status="pending",
        proposed_by=user_id,
    )
    db.add(variety)
    db.flush()
    return variety


def approve_variety(
    db: Session,
    variety: Variety,
    reviewer_id: str,
    *,
    crop_id: object | None = None,
    kana: str | None = None,
    seed_type: str | None = None,
    summary: str | None = None,
) -> None:
    """品種マスタを承認する(運営者のみ。admin アプリから使う)。

    承認と同時に辞典の記事枠を自動作成し、提案者へメール通知する。
    表記ゆれの正規化(かな・種別・品目紐付け)はここで確定する。
    """
    from app.services import dictionary, mail  # 循環 import 回避

    variety.status = "approved"
    variety.reviewed_by = reviewer_id
    if crop_id is not None:
        variety.crop_id = crop_id  # type: ignore[assignment]
    if kana:
        variety.kana = kana
    if seed_type:
        variety.seed_type = seed_type
    if summary:
        variety.summary = summary
    dictionary.ensure_article(db, variety)
    db.flush()
    if variety.proposed_by:
        mail.send_to_user(
            variety.proposed_by,
            f"[種の交換] 品種「{variety.name}」が承認されました",
            "辞典の記事枠ができました。編集を提案できます。",
        )


def reject_variety(
    db: Session,
    variety: Variety,
    reviewer_id: str,
    *,
    is_registered: bool = False,
    note: str | None = None,
) -> int:
    """品種提案を却下する。登録品種なら該当出品を flagged に落とす。

    戻り値は flagged にした出品の数。
    """
    import datetime

    from app.models import Listing
    from app.services import mail

    variety.status = "rejected"
    variety.reviewed_by = reviewer_id
    flagged = 0
    if is_registered:
        # 種苗法対応: 登録品種の確定。以後の出品はブロックされる
        variety.is_registered_variety = True
        variety.registration_note = note
        variety.registration_checked_at = datetime.datetime.now(datetime.UTC)
        variety.registration_checked_by = reviewer_id
        listings = db.scalars(
            select(Listing).where(
                Listing.variety_id == variety.id,
                Listing.moderation == "approved",
            )
        ).all()
        for listing in listings:
            listing.moderation = "flagged"
            flagged += 1
            mail.send_to_user(
                listing.user_id,
                "[種の交換] 出品を一時停止しました",
                f"「{variety.name}」は登録品種と確認されたため出品を"
                "停止しました。お心当たりがない場合はご連絡ください。",
            )
    db.flush()
    if variety.proposed_by:
        mail.send_to_user(
            variety.proposed_by,
            f"[種の交換] 品種「{variety.name}」の提案は見送られました",
            note or "詳細は運営までお問い合わせください。",
        )
    return flagged
