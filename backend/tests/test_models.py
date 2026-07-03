# SPDX-License-Identifier: AGPL-3.0-only
"""SQLAlchemy モデルと schema.sql(=正)の突合。"""

import psycopg

from app.core.db import Base
from tests.conftest import TEST_DSN


def _db_columns() -> dict[tuple[str, str], set[str]]:
    query = """
        SELECT table_schema, table_name, column_name
        FROM information_schema.columns
        WHERE table_schema IN ('shared', 'exchange', 'dictionary')
    """
    tables: dict[tuple[str, str], set[str]] = {}
    with psycopg.connect(TEST_DSN) as conn:
        for schema, table, column in conn.execute(query):
            tables.setdefault((schema, table), set()).add(column)
    return tables


def test_models_match_schema() -> None:
    db_tables = _db_columns()
    model_tables = {
        (table.schema, table.name): {c.name for c in table.columns}
        for table in Base.metadata.tables.values()
    }
    # モデルが持つテーブル・列は全て DB に存在し、列集合が一致すること
    assert set(model_tables) == set(db_tables), (
        f"モデルとDBのテーブルがずれています: "
        f"モデルのみ={set(model_tables) - set(db_tables)} "
        f"DBのみ={set(db_tables) - set(model_tables)}"
    )
    for key, columns in model_tables.items():
        assert columns == db_tables[key], (
            f"{key} の列がずれています: "
            f"モデルのみ={columns - db_tables[key]} "
            f"DBのみ={db_tables[key] - columns}"
        )
