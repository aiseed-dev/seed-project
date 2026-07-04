# SPDX-License-Identifier: AGPL-3.0-only
"""GET /varieties(公開・pg_trgm 検索)。"""

import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.core.auth import require_user
from app.core.db import get_db
from app.core.errors import ApiError
from app.models import Variety
from app.schemas.articles import VarietyPropose
from app.schemas.varieties import VarietyOut
from app.services.variety import resolve_free_name

router = APIRouter(tags=["varieties"])


@router.get("/varieties")
def search_varieties(
    q: str = Query(default="", max_length=100),
    limit: int = Query(default=20, ge=1, le=50),
    db: Session = Depends(get_db),
) -> list[VarietyOut]:
    stmt = select(Variety).where(Variety.status == "approved")
    if q:
        pattern = f"%{q}%"
        stmt = stmt.where(
            or_(
                Variety.name.ilike(pattern),
                Variety.kana.ilike(pattern),
                Variety.aliases.any(q),
                Variety.name.op("%")(q),  # pg_trgm の類似一致
            )
        ).order_by(func.similarity(Variety.name, q).desc())
    else:
        stmt = stmt.order_by(Variety.name)
    rows = db.scalars(stmt.limit(limit)).all()
    return [VarietyOut.model_validate(row) for row in rows]


@router.get("/varieties/{variety_id}")
def get_variety(variety_id: uuid.UUID, db: Session = Depends(get_db)) -> VarietyOut:
    variety = db.get(Variety, variety_id)
    if variety is None or variety.status != "approved":
        raise ApiError(404, "NOT_FOUND", "品種が見つかりません")
    return VarietyOut.model_validate(variety)


@router.post("/varieties", status_code=201)
def propose_variety(
    payload: VarietyPropose,
    user_id: str = Depends(require_user),
    db: Session = Depends(get_db),
) -> VarietyOut:
    """品種マスタへの新規提案(pending)。承認は運営者(admin アプリ)。"""
    variety = resolve_free_name(db, payload.name, payload.category_id, user_id)
    if variety.status == "pending" and variety.proposed_by == user_id:
        variety.kana = payload.kana or variety.kana
        variety.crop_name = payload.crop_name or variety.crop_name
        variety.summary = payload.summary or variety.summary
    db.commit()
    db.refresh(variety)
    return VarietyOut.model_validate(variety)
