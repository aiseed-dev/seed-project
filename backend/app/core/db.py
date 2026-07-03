# SPDX-License-Identifier: AGPL-3.0-only
"""SQLAlchemy 2.0 のエンジンとセッション。

モデル定義(Mapped[])は Phase 1 で schema.sql と突き合わせて実装する。
schema.sql とモデルがずれたら schema.sql が正。
"""

from collections.abc import Iterator
from functools import lru_cache

from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import settings


class Base(DeclarativeBase):
    pass


@lru_cache
def engine() -> Engine:
    return create_engine(settings().database_url)


def get_db() -> Iterator[Session]:
    """FastAPI 依存性: リクエストごとのセッション。"""
    maker = sessionmaker(bind=engine())
    db = maker()
    try:
        yield db
    finally:
        db.close()
