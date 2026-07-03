from pathlib import Path

import pytest

import pamphlet

PDF = Path(__file__).parent.parent / "data" / "2026main.pdf"


def test_parse_order_line_multi() -> None:
    line = "0063 つるありいんげん ミックス ¥360 0101 コールラビ ホワイトヴィエナ ¥360"
    assert pamphlet.parse_order_line(line) == [
        ("0063", "つるありいんげん ミックス", 360),
        ("0101", "コールラビ ホワイトヴィエナ", 360),
    ]


def test_parse_order_line_comma_price() -> None:
    assert pamphlet.parse_order_line("0015 グラウンドペチカ ¥2,460") == [
        ("0015", "グラウンドペチカ", 2460)
    ]


def test_parse_order_line_skips_priceless_run() -> None:
    # 価格のないテキストを挟んでも後続の品目を取りこぼさない
    line = "FFAAXX 050-4462-2655 または 042-982-5023 0065 いんげん ボルロット ¥360"
    assert pamphlet.parse_order_line(line) == [("0065", "いんげん ボルロット", 360)]


def test_is_banner() -> None:
    assert pamphlet._is_banner("オオククララ")
    assert pamphlet._is_banner("00008888")
    assert not pamphlet._is_banner("0088")  # 4桁品番は装飾扱いしない
    assert not pamphlet._is_banner("ししとう")


def test_classify_cell_vegetable() -> None:
    lines = [
        (0.0, "0081"),
        (10.0, "Okra Hill Country"),
        (20.0, "オクラ ヒルカントリーレッド"),
        (30.0, "アオイ科 約30粒入"),
        (40.0, "蒔き時：4月下旬〜5月"),
        (50.0, "収 穫：7月〜10月"),
        (60.0, "テキサス州南部の伝統品種で緑"),
        (70.0, "色に赤味がかった色合いのオクラ。"),
        (100.0, "P 8"),  # 行間が空く → ページの別要素として無視
    ]
    d = pamphlet.classify_cell("0081", lines, "オクラ")
    assert d.en == "Okra Hill Country"
    assert d.name == "オクラ ヒルカントリーレッド"
    assert d.family == "アオイ科"
    assert d.amount == "約30粒入"
    assert d.sow == "蒔き時：4月下旬〜5月"
    assert d.harvest == "収 穫：7月〜10月"
    assert d.desc == "テキサス州南部の伝統品種で緑色に赤味がかった色合いのオクラ。"
    assert "P 8" not in d.desc


def test_classify_cell_flower_and_potato() -> None:
    d = pamphlet.classify_cell(
        "1055",
        [(0.0, "マメ科 約30粒入"), (10.0, "花 期：4月〜6月"), (20.0, "説明文。")],
        "花",
    )
    assert d.harvest == "花 期：4月〜6月"
    assert d.desc == "説明文。"

    d = pamphlet.classify_cell("0015", [(0.0, "植えつけ：2月〜3月")], "")
    assert d.sow == "植えつけ：2月〜3月"


@pytest.mark.skipif(not PDF.exists(), reason="カタログPDF現物がある場合のみ")
def test_parse_real_pdf(tmp_path: Path) -> None:
    entries = pamphlet.parse(PDF)
    assert len(entries) >= 250
    by_code = {e.code: e for e in entries}
    assert by_code["0001"].price == 360
    assert by_code["0015"].price == 2460
    assert by_code["0088"].detail is not None  # 同数字ペアの品番も拾う
    assert by_code["0088"].detail.family == "アブラナ科"
    assert all(e.price > 0 for e in entries)

    out = tmp_path / "台帳.xlsx"
    pamphlet.write_ledger(entries, out)
    import ledger

    items = ledger.read_items(out)
    assert len(items) == len(entries)
    assert all(i.stock == "販売中" for i in items)
