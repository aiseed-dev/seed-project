# SPDX-License-Identifier: AGPL-3.0-only
"""dictionary スキーマ(辞典記事・リビジョン・記事写真)。"""

import datetime
import uuid

from sqlalchemy import ForeignKey, Integer, Text, text
from sqlalchemy.dialects.postgresql import JSONB, TIMESTAMP, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base

_now = text("now()")


class Article(Base):
    __tablename__ = "articles"
    __table_args__ = {"schema": "dictionary"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    variety_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("shared.varieties.id"), unique=True
    )
    current_revision_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("dictionary.revisions.id", use_alter=True)
    )
    created_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )


class Revision(Base):
    __tablename__ = "revisions"
    __table_args__ = {"schema": "dictionary"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    article_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("dictionary.articles.id", ondelete="CASCADE")
    )
    author_id: Mapped[str] = mapped_column(ForeignKey("shared.app_users.id"))
    content: Mapped[dict[str, str]] = mapped_column(JSONB)
    edit_summary: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(Text, server_default=text("'pending'"))
    reviewed_by: Mapped[str | None] = mapped_column(ForeignKey("shared.app_users.id"))
    review_note: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )


class ArticlePhoto(Base):
    __tablename__ = "article_photos"
    __table_args__ = {"schema": "dictionary"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    article_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("dictionary.articles.id", ondelete="CASCADE")
    )
    uploaded_by: Mapped[str] = mapped_column(ForeignKey("shared.app_users.id"))
    path: Mapped[str] = mapped_column(Text)
    caption: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(Text, server_default=text("'pending'"))
    sort_order: Mapped[int] = mapped_column(Integer, server_default=text("0"))
