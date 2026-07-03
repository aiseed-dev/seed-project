from pathlib import Path

import pytest

import catalog
import ledger


@pytest.fixture
def book(tmp_path: Path) -> Path:
    path = tmp_path / "台帳.xlsx"
    ledger.new(path, sample=True)
    return path


def test_build_outputs(book: Path, tmp_path: Path) -> None:
    out = tmp_path / "catalog"
    written = catalog.build(book, out)
    assert (out / "index.html") in written
    assert (out / "style.css").exists()


def test_index_grouped_by_category(book: Path, tmp_path: Path) -> None:
    out = tmp_path / "catalog"
    catalog.build(book, out)
    html = (out / "index.html").read_text(encoding="utf-8")
    assert "なす" in html
    assert "菜っ葉" in html
    assert "真黒茄子" in html
    assert "たねの店(サンプル)" in html


def test_soldout_and_ended(book: Path, tmp_path: Path) -> None:
    out = tmp_path / "catalog"
    catalog.build(book, out)
    html = (out / "index.html").read_text(encoding="utf-8")
    # 品切れは表示+注記、終了はカタログに載せない
    assert "ただいま品切れ中です" in html
    assert "打木赤皮甘栗かぼちゃ" not in html
    assert not (out / "items" / "C-001.html").exists()


def test_item_pages(book: Path, tmp_path: Path) -> None:
    out = tmp_path / "catalog"
    catalog.build(book, out)
    page = (out / "items" / "A-001.html").read_text(encoding="utf-8")
    assert "真黒茄子" in page
    assert "A-001" in page
    assert "440" in page
    assert "埼玉県" in page


def test_html_escapes_user_text(book: Path, tmp_path: Path) -> None:
    from openpyxl import load_workbook

    wb = load_workbook(book)
    ws = wb["商品"]
    ws.append(
        ["Z-001", "<b>怪しい品種</b>", "固定種", 100, "", "", "", "販売中", "その他"]
    )
    wb.save(book)
    out = tmp_path / "catalog"
    catalog.build(book, out)
    html = (out / "index.html").read_text(encoding="utf-8")
    assert "<b>怪しい品種</b>" not in html
    assert "&lt;b&gt;怪しい品種&lt;/b&gt;" in html
