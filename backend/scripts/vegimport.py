# SPDX-License-Identifier: AGPL-3.0-only
"""vegitage-data(正本 Markdown)を辞典に取り込む。

vegitage-data/web/<地域>/ の作物ごとの原稿(概要+history/cultivation/
cuisine)を、品種マスタ(承認済み)+辞典記事(公開リビジョン)として投入する。
出典は vegitage-data(aiseed.dev, CC BY 4.0)。取り込み後の分類・品目の
正規化は admin アプリで行う。再実行しても既存の作物はスキップする。

実行: python scripts/vegimport.py [--root ../../vegitage/vegitage-data/web/italian]
"""

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import select  # noqa: E402
from sqlalchemy.orm import Session, sessionmaker  # noqa: E402

from app.core.db import engine  # noqa: E402
from app.models import AppUser, Article, Category, Variety  # noqa: E402
from app.services.dictionary import approve_revision, submit_revision  # noqa: E402

IMPORT_USER = "vegitage-import"

# 分類の粗い自動判定(取り込み後に admin で正規化する)
KEYWORDS = {
    "grains": ["そば", "麦", "とうもろこし", "米"],
    "beans": ["豆", "レンズ", "ひよこ", "ルピナス"],
    "herbs": [
        "バジル",
        "パセリ",
        "ローズマリー",
        "セージ",
        "ハーブ",
        "オレガノ",
        "タイム",
        "ミント",
        "フェンネル",
    ],
    "root-veg": [
        "大根",
        "かぶ",
        "にんじん",
        "ビート",
        "ごぼう",
        "玉ねぎ",
        "にんにく",
        "ラディッシュ",
    ],
    "fruit-veg": [
        "トマト",
        "ナス",
        "茄子",
        "ズッキーニ",
        "かぼちゃ",
        "南瓜",
        "ピーマン",
        "とうがらし",
        "唐辛子",
        "きゅうり",
        "胡瓜",
        "アーティチョーク",
        "メロン",
        "スイカ",
    ],
}


def guess_category(db: Session, name: str) -> int:
    slug = "leaf-veg"
    for candidate, words in KEYWORDS.items():
        if any(word in name for word in words):
            slug = candidate
            break
    category = db.scalars(select(Category).where(Category.slug == slug)).one()
    return category.id


def summary_of(text: str) -> str:
    """概要mdの斜体キャッチ行(なければ最初の段落)を要約に使う。"""
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("*") and stripped.endswith("*"):
            return stripped.strip("*").strip()[:200]
    for line in text.splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith(("#", "-", "*", "|")):
            return stripped[:200]
    return ""


def section_of(root: Path, kind: str, name: str) -> str | None:
    path = root / kind / f"{name}.md"
    if not path.exists():
        return None
    text = path.read_text(encoding="utf-8").strip()
    # 先頭の H1(作物名の繰り返し)は落とす
    lines = text.splitlines()
    if lines and lines[0].startswith("# "):
        lines = lines[1:]
    return "\n".join(lines).strip() or None


NATURAL_HEADING = re.compile(r"^(#{2,3})\s.*(自然|有機).*")


def split_natural(cultivation: str | None) -> tuple[str | None, str | None]:
    """栽培原稿から「自然栽培・有機栽培のポイント」の節を切り出す。

    見出し(H2/H3)に「自然」or「有機」を含む節を natural_farming に、
    残りを cultivation に分ける。該当なしなら (原文, None)。
    """
    if not cultivation:
        return cultivation, None
    lines = cultivation.splitlines()
    start = level = None
    for index, line in enumerate(lines):
        match = NATURAL_HEADING.match(line)
        if match:
            start, level = index, len(match.group(1))
            break
    if start is None:
        return cultivation, None
    end = len(lines)
    for index in range(start + 1, len(lines)):
        if re.match(rf"^#{{2,{level}}}\s", lines[index]):
            end = index
            break
    natural = "\n".join(lines[start:end]).strip()
    rest = "\n".join(lines[:start] + lines[end:]).strip()
    return (rest or None), (natural or None)


def run(
    db: Session, root: Path, limit: int | None, refresh: bool = False
) -> tuple[int, int]:
    if db.get(AppUser, IMPORT_USER) is None:
        db.add(AppUser(id=IMPORT_USER, display_name="vegitage-data 取込"))
        db.flush()

    imported = skipped = 0
    overviews = sorted(root.glob("*.md"))
    for path in overviews[:limit]:
        name = path.stem
        if name.upper() == "README":
            continue
        existing = db.scalars(select(Variety).where(Variety.name == name)).first()
        if existing is not None:
            has_article = db.scalars(
                select(Article).where(Article.variety_id == existing.id)
            ).first()
            if (
                has_article is not None
                and has_article.current_revision_id
                and not refresh
            ):
                skipped += 1
                continue
            variety = existing
        else:
            overview = path.read_text(encoding="utf-8")
            variety = Variety(
                name=name,
                category_id=guess_category(db, name),
                seed_type="unknown",
                summary=summary_of(overview),
                status="approved",
                proposed_by=IMPORT_USER,
                reviewed_by=IMPORT_USER,
            )
            db.add(variety)
            db.flush()

        content: dict[str, str] = {}
        for section, kind in [
            ("history", "history"),
            ("cultivation", "cultivation"),
            ("cooking", "cuisine"),
        ]:
            body = section_of(root, kind, name)
            if section == "cultivation":
                # 自然栽培・有機栽培の節は独立セクションへ(実践者の受け皿)
                body, natural = split_natural(body)
                if natural:
                    content["natural_farming"] = natural
            if body:
                content[section] = body
        content["sources"] = (
            "vegitage-data(aiseed.dev)の調査原稿を基に作成(CC BY 4.0)。"
        )
        revision = submit_revision(
            db, variety, IMPORT_USER, content, "vegitage-data から取込"
        )
        approve_revision(db, revision, IMPORT_USER)
        imported += 1
    db.commit()
    return imported, skipped


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="vegitage-data を辞典へ取り込む")
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).parents[3] / "vegitage" / "vegitage-data" / "web" / "italian",
    )
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument(
        "--refresh",
        action="store_true",
        help="既存記事にも新リビジョンを重ねて更新する",
    )
    args = parser.parse_args(argv)
    if not args.root.is_dir():
        print(f"見つかりません: {args.root}", file=sys.stderr)
        return 1
    maker = sessionmaker(bind=engine())
    with maker() as db:
        imported, skipped = run(db, args.root, args.limit, refresh=args.refresh)
    print(f"取込 {imported} 件 / スキップ {skipped} 件")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
