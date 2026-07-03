# SPDX-License-Identifier: AGPL-3.0-only
"""db/schema.sql を PostgreSQL に適用する(Phase 0 の初期化用)。

マイグレーションは Phase 1 から alembic に移行する。
"""

import argparse
import os
import sys
from pathlib import Path

import psycopg

SCHEMA = Path(__file__).parent.parent / "db" / "schema.sql"
DEFAULT_DSN = "postgresql://seed:seed@localhost:5432/seed"


def apply_schema(dsn: str, schema_path: Path = SCHEMA) -> None:
    sql = schema_path.read_text(encoding="utf-8")
    with psycopg.connect(dsn, autocommit=True) as conn:
        # 113行目の GIN インデックス(gin_trgm_ops)が必要とする拡張
        conn.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
        conn.execute(sql)  # type: ignore[arg-type]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="schema.sql を適用する")
    parser.add_argument(
        "--dsn",
        default=os.environ.get("SEED_DSN", DEFAULT_DSN),
        help="接続文字列(既定: 環境変数 SEED_DSN または開発用ローカル)",
    )
    args = parser.parse_args(argv)
    try:
        apply_schema(args.dsn)
    except psycopg.Error as e:
        print(f"適用に失敗しました: {e}", file=sys.stderr)
        return 1
    print("schema.sql を適用しました")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
