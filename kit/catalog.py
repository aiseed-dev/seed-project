"""商品台帳 xlsx からカタログ HTML を生成する。

カテゴリ別一覧(index.html)+品目ページ(items/品番.html)。
カードの様式は docs/10(種苗カタログ様式)の簡略適用。
"""

from __future__ import annotations

import argparse
import html
import shutil
from pathlib import Path

from ledger import Item, Shop, read_items, read_shop

TEMPLATES = Path(__file__).parent / "templates"


def _esc(s: str) -> str:
    return html.escape(s, quote=True)


def _page(shop: Shop, title: str, body: str, root: str) -> str:
    base = (TEMPLATES / "base.html").read_text(encoding="utf-8")
    contact = " / ".join(x for x in [shop.address, shop.tel, shop.email] if x)
    return base.format(
        title=_esc(title),
        shop_name=_esc(shop.name),
        contact=_esc(contact),
        body=body,
        root=root,
    )


def _price_html(shop: Shop, item: Item) -> str:
    note = "税込" if shop.tax_included else "税別"
    return f'<div class="price">{item.price:,}円 <small>({note})</small></div>'


def _spec_table(item: Item, with_code: bool = False) -> str:
    rows = []
    if with_code:
        rows.append(f"<tr><th>品番</th><td>{_esc(item.code)}</td></tr>")
    if item.origin:
        rows.append(f"<tr><th>生産地</th><td>{_esc(item.origin)}</td></tr>")
    if item.germination:
        rows.append(f"<tr><th>発芽率</th><td>{_esc(item.germination)}</td></tr>")
    return f'<table class="spec">{"".join(rows)}</table>' if rows else ""


def _stock_html(item: Item) -> str:
    if item.stock == "品切れ":
        return '<div class="soldout">ただいま品切れ中です</div>'
    return ""


def _card(shop: Shop, item: Item) -> str:
    parts = [
        f'<div class="name"><a href="items/{_esc(item.code)}.html">'
        f"{_esc(item.name)}</a></div>",
        f'<div><span class="chip">{_esc(item.kind)}</span></div>' if item.kind else "",
        _spec_table(item),
        _price_html(shop, item),
        _stock_html(item),
    ]
    return f'<div class="card">{"".join(p for p in parts if p)}</div>'


def _index_body(shop: Shop, items: list[Item]) -> str:
    categories: dict[str, list[Item]] = {}
    for item in items:
        categories.setdefault(item.category, []).append(item)
    sections = []
    for category, members in categories.items():
        cards = "".join(_card(shop, m) for m in members)
        sections.append(
            f'<h2 class="category">{_esc(category)}'
            f'<span class="count">{len(members)}件</span></h2>'
            f'<div class="grid">{cards}</div>'
        )
    return "".join(sections)


def _item_body(shop: Shop, item: Item) -> str:
    chip = f' <span class="chip">{_esc(item.kind)}</span>' if item.kind else ""
    parts = [
        '<nav class="crumb"><a href="../index.html">カタログ</a>'
        f" / {_esc(item.category)} / {_esc(item.name)}</nav>",
        '<div class="card">',
        f'<div class="name">{_esc(item.name)}{chip}</div>',
        f'<div class="desc">{_esc(item.desc)}</div>' if item.desc else "",
        _spec_table(item, with_code=True),
        _price_html(shop, item),
        _stock_html(item),
        "</div>",
    ]
    return "".join(p for p in parts if p)


def build(ledger_path: Path, out: Path) -> list[Path]:
    """カタログ一式を out に生成し、生成したファイル一覧を返す。"""
    shop = read_shop(ledger_path)
    items = [i for i in read_items(ledger_path) if i.stock != "終了"]

    out.mkdir(parents=True, exist_ok=True)
    (out / "items").mkdir(exist_ok=True)
    written: list[Path] = []

    css = out / "style.css"
    shutil.copyfile(TEMPLATES / "style.css", css)
    written.append(css)

    index = out / "index.html"
    index.write_text(
        _page(shop, f"{shop.name} カタログ", _index_body(shop, items), root=""),
        encoding="utf-8",
    )
    written.append(index)

    for item in items:
        page = out / "items" / f"{item.code}.html"
        page.write_text(
            _page(shop, f"{item.name} — {shop.name}", _item_body(shop, item), "../"),
            encoding="utf-8",
        )
        written.append(page)
    return written


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="台帳からカタログHTMLを生成する")
    parser.add_argument("ledger", type=Path, help="商品台帳 xlsx")
    parser.add_argument(
        "-o", "--out", type=Path, default=Path("catalog"), help="出力先ディレクトリ"
    )
    args = parser.parse_args(argv)
    written = build(args.ledger, args.out)
    print(f"{len(written)} ファイルを生成しました: {args.out}/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
