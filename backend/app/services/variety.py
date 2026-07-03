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
