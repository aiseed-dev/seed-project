# SPDX-License-Identifier: AGPL-3.0-only
"""editor API(docs/03)。辞典リビジョン承認。外部協力者が使う唯一の管理系。

役割付与は運営者が管理アプリで行う(role: editor / moderator / admin)。
"""

import uuid

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.auth import require_user
from app.core.db import get_db
from app.core.errors import ApiError
from app.models import AppUser, Article, Revision, Variety
from app.schemas.articles import (
    RevisionDetailOut,
    RevisionOut,
    RevisionPatch,
    RevisionQueueEntry,
)
from app.services import dictionary

router = APIRouter(tags=["editor"])

EDITOR_ROLES = ("editor", "moderator", "admin")


def require_editor(
    user_id: str = Depends(require_user), db: Session = Depends(get_db)
) -> str:
    user = db.get(AppUser, user_id)
    if user is None or user.role not in EDITOR_ROLES:
        raise ApiError(403, "NOT_EDITOR", "editor 権限が必要です")
    return user_id


def _variety_name(db: Session, revision: Revision) -> str:
    row = db.execute(
        select(Variety.name)
        .join(Article, Article.variety_id == Variety.id)
        .where(Article.id == revision.article_id)
    ).first()
    return row[0] if row else ""


@router.get("/editor/revisions")
def revision_queue(
    status: str = "pending",
    user_id: str = Depends(require_editor),
    db: Session = Depends(get_db),
) -> list[RevisionQueueEntry]:
    rows = db.scalars(
        select(Revision)
        .where(Revision.status == status)
        .order_by(Revision.created_at)  # 古い順
    ).all()
    entries = []
    for revision in rows:
        author = db.get(AppUser, revision.author_id)
        entries.append(
            RevisionQueueEntry(
                revision=RevisionOut.model_validate(revision),
                variety_name=_variety_name(db, revision),
                author_name=author.display_name if author else "",
            )
        )
    return entries


@router.get("/editor/revisions/{revision_id}")
def revision_detail(
    revision_id: uuid.UUID,
    user_id: str = Depends(require_editor),
    db: Session = Depends(get_db),
) -> RevisionDetailOut:
    revision = db.get(Revision, revision_id)
    if revision is None:
        raise ApiError(404, "NOT_FOUND", "リビジョンが見つかりません")
    article = db.get(Article, revision.article_id)
    old = dictionary.current_content(db, article) if article else {}
    new = dict(revision.content)
    return RevisionDetailOut(
        revision=RevisionOut.model_validate(revision),
        variety_name=_variety_name(db, revision),
        content=new,
        diff=dictionary.section_diff(old, new),  # 差分はサーバー側で計算
    )


@router.patch("/editor/revisions/{revision_id}")
def review_revision(
    revision_id: uuid.UUID,
    payload: RevisionPatch,
    user_id: str = Depends(require_editor),
    db: Session = Depends(get_db),
) -> RevisionOut:
    revision = db.get(Revision, revision_id)
    if revision is None:
        raise ApiError(404, "NOT_FOUND", "リビジョンが見つかりません")
    if revision.status != "pending":
        raise ApiError(409, "ALREADY_REVIEWED", "レビュー済みです")
    if payload.action == "approve":
        dictionary.approve_revision(db, revision, user_id)
    else:
        if not (payload.review_note and payload.review_note.strip()):
            raise ApiError(422, "REVIEW_NOTE_REQUIRED", "却下理由が必要です")
        dictionary.reject_revision(db, revision, user_id, payload.review_note)
    db.commit()
    db.refresh(revision)
    return RevisionOut.model_validate(revision)
