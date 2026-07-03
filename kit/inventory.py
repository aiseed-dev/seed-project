"""店側在庫APIの最小実装(ステップ1の台帳から)。

`GET /inventory` → [{"item_code": 品番, "qty": 在庫数}, ...]
台帳に「在庫数」列があればその値、無ければ在庫状態から
販売中=1 / それ以外=0 を返す(番号付き在庫表と同じ考え方)。

起動: python inventory.py 台帳.xlsx --port 8801
aiseed 側はこの標準HTTP+JSONを読む(在庫の正は店側)。
"""

from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

from ledger import read_items


def inventory(ledger_path: Path) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for item in read_items(ledger_path):
        raw = item.extra.get("在庫数")
        if raw is not None and str(raw).strip().isdigit():
            qty = int(str(raw).strip())
        else:
            qty = 1 if item.stock == "販売中" else 0
        rows.append({"item_code": item.code, "qty": qty})
    return rows


class Handler(BaseHTTPRequestHandler):
    ledger_path: Path

    def do_GET(self) -> None:  # noqa: N802 (http.server の規約)
        if self.path.rstrip("/") != "/inventory":
            self.send_error(404)
            return
        payload = json.dumps(inventory(self.ledger_path), ensure_ascii=False).encode(
            "utf-8"
        )
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format: str, *args: object) -> None:
        pass  # 静かに


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="台帳から在庫APIを提供する")
    parser.add_argument("ledger", type=Path, help="商品台帳 xlsx")
    parser.add_argument("--port", type=int, default=8801)
    args = parser.parse_args(argv)
    Handler.ledger_path = args.ledger
    server = HTTPServer(("0.0.0.0", args.port), Handler)
    print(f"在庫API: http://localhost:{args.port}/inventory")
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
