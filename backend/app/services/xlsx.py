# SPDX-License-Identifier: AGPL-3.0-only
"""帳票の生成(openpyxl 直接生成)。店舗のエクスポートで使う。"""

import csv
import io

from openpyxl import Workbook

LISTING_HEADERS = ["品種名", "タイトル", "種別", "価格", "状態", "作成日"]
DEAL_HEADERS = [
    "申込番号",
    "店舗コード",
    "受付日",
    "承諾日",
    "承諾担当者",
    "成約日",
    "相手",
    "品目",
    "数量",
    "金額",
]


def to_xlsx(headers: list[str], rows: list[list[object]], title: str) -> bytes:
    wb = Workbook()
    ws = wb.active
    assert ws is not None
    ws.title = title
    ws.append(headers)
    for row in rows:
        ws.append(row)
    buffer = io.BytesIO()
    wb.save(buffer)
    return buffer.getvalue()


def to_csv(headers: list[str], rows: list[list[object]]) -> bytes:
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(headers)
    writer.writerows(rows)
    return buffer.getvalue().encode("utf-8-sig")  # Excel 互換
