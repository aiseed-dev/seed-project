# SPDX-License-Identifier: AGPL-3.0-only
"""GET /categories(公開)。"""

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.models import Category
from app.schemas.categories import CategoryOut

router = APIRouter(tags=["categories"])


@router.get("/categories")
def list_categories(db: Session = Depends(get_db)) -> list[CategoryOut]:
    rows = db.scalars(select(Category).order_by(Category.sort_order)).all()
    return [CategoryOut.model_validate(row) for row in rows]
