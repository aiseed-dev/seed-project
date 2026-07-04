# SPDX-License-Identifier: AGPL-3.0-only
"""辞典記事 API(docs/03)。コンテンツは CC BY-SA 4.0。"""

import uuid

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.auth import require_user
from app.core.db import get_db
from app.core.errors import ApiError
from app.models import Article, Revision, Variety
from app.schemas.articles import ArticleOut, RevisionCreate, RevisionOut
from app.services import dictionary

router = APIRouter(tags=["articles"])


def _approved_variety(db: Session, variety_id: uuid.UUID) -> Variety:
    variety = db.get(Variety, variety_id)
    if variety is None or variety.status != "approved":
        raise ApiError(404, "NOT_FOUND", "品種が見つかりません")
    return variety


@router.get("/articles/export")
def export_articles(db: Session = Depends(get_db)) -> list[ArticleOut]:
    """辞典記事の一括JSON(CC BY-SA の持ち出し保証。認証不要)。"""
    rows = db.execute(
        select(Article, Variety, Revision)
        .join(Variety, Article.variety_id == Variety.id)
        .join(Revision, Article.current_revision_id == Revision.id)
        .order_by(Variety.name)
    ).all()
    return [
        ArticleOut(
            variety_id=variety.id,
            variety_name=variety.name,
            content=dict(revision.content),
            updated_at=revision.created_at,
        )
        for _, variety, revision in rows
    ]


@router.get("/articles/{variety_id}")
def get_article(variety_id: uuid.UUID, db: Session = Depends(get_db)) -> ArticleOut:
    variety = _approved_variety(db, variety_id)
    article = db.scalars(
        select(Article).where(Article.variety_id == variety.id)
    ).first()
    if article is None or article.current_revision_id is None:
        # 記事枠なし or 公開リビジョンなし=準備中(空コンテンツで返す)
        return ArticleOut(
            variety_id=variety.id,
            variety_name=variety.name,
            content={},
            updated_at=None,
        )
    revision = db.get(Revision, article.current_revision_id)
    return ArticleOut(
        variety_id=variety.id,
        variety_name=variety.name,
        content=dict(revision.content) if revision else {},
        updated_at=revision.created_at if revision else None,
    )


@router.post("/articles/{variety_id}/revisions", status_code=201)
def create_revision(
    variety_id: uuid.UUID,
    payload: RevisionCreate,
    user_id: str = Depends(require_user),
    db: Session = Depends(get_db),
) -> RevisionOut:
    variety = _approved_variety(db, variety_id)
    revision = dictionary.submit_revision(
        db, variety, user_id, payload.content, payload.edit_summary
    )
    db.commit()
    db.refresh(revision)
    return RevisionOut.model_validate(revision)


@router.get("/me/revisions")
def my_revisions(
    user_id: str = Depends(require_user), db: Session = Depends(get_db)
) -> list[RevisionOut]:
    rows = db.scalars(
        select(Revision)
        .where(Revision.author_id == user_id)
        .order_by(Revision.created_at.desc())
    ).all()
    return [RevisionOut.model_validate(r) for r in rows]
