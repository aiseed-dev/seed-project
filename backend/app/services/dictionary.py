# SPDX-License-Identifier: AGPL-3.0-only
"""辞典のリビジョン承認フロー(editor API と admin アプリの双方から使う)。

- 記事は品種と1:1。品種のマスタ承認時に記事枠を自動作成する
- 差分計算はサーバー側(difflib)。Flutter は色を塗るだけ
"""

import difflib

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.models import Article, Revision, Variety
from app.services import mail

SECTIONS = ["history", "cultivation", "seed_saving", "cooking", "sources"]


def ensure_article(db: Session, variety: Variety) -> Article:
    """記事枠を返す(無ければ作成)。承認済み品種のみ。"""
    article = db.scalars(
        select(Article).where(Article.variety_id == variety.id)
    ).first()
    if article is None:
        article = Article(variety_id=variety.id)
        db.add(article)
        db.flush()
    return article


def submit_revision(
    db: Session,
    variety: Variety,
    author_id: str,
    content: dict[str, str],
    edit_summary: str | None,
) -> Revision:
    """編集提案(pending)を受け付ける。"""
    unknown = set(content) - set(SECTIONS)
    if unknown:
        raise ApiError(422, "SECTION_INVALID", f"不明なセクション: {unknown}")
    article = ensure_article(db, variety)
    revision = Revision(
        article_id=article.id,
        author_id=author_id,
        content=content,
        edit_summary=edit_summary,
    )
    db.add(revision)
    db.flush()
    return revision


def current_content(db: Session, article: Article) -> dict[str, str]:
    if article.current_revision_id is None:
        return {}
    current = db.get(Revision, article.current_revision_id)
    return dict(current.content) if current else {}


def section_diff(
    old: dict[str, str], new: dict[str, str]
) -> dict[str, list[dict[str, str]]]:
    """セクション別の行差分。op: keep / add / del。"""
    result: dict[str, list[dict[str, str]]] = {}
    for section in SECTIONS:
        before = (old.get(section) or "").splitlines()
        after = (new.get(section) or "").splitlines()
        if not before and not after:
            continue
        lines: list[dict[str, str]] = []
        for token in difflib.ndiff(before, after):
            op = {" ": "keep", "+": "add", "-": "del"}.get(token[:1])
            if op is not None:
                lines.append({"text": token[2:], "op": op})
        result[section] = lines
    return result


def approve_revision(db: Session, revision: Revision, reviewer_id: str) -> None:
    revision.status = "approved"
    revision.reviewed_by = reviewer_id
    article = db.get(Article, revision.article_id)
    if article is not None:
        article.current_revision_id = revision.id
    db.flush()
    mail.send_to_user(
        revision.author_id,
        "[種の交換] 辞典の編集提案が承認されました",
        revision.edit_summary or "提案が公開されました。",
    )


def reject_revision(
    db: Session, revision: Revision, reviewer_id: str, review_note: str
) -> None:
    revision.status = "rejected"
    revision.reviewed_by = reviewer_id
    revision.review_note = review_note
    db.flush()
    mail.send_to_user(
        revision.author_id,
        "[種の交換] 辞典の編集提案が見送られました",
        f"理由: {review_note}",
    )
