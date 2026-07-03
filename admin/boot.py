# SPDX-License-Identifier: MIT
"""backend(models / services)への接続。

DB 直結・認証なし(アプリを起動できる=DB 認証情報を持つ運営者)。
DATABASE_URL は backend と同じ環境変数(seed_database_url)を読む。
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "backend"))

from app.core.db import engine  # noqa: E402
from sqlalchemy.orm import Session, sessionmaker  # noqa: E402


def session() -> Session:
    """view ごとに開く短命セッション(自己完結型の方針)。"""
    return sessionmaker(bind=engine())()
