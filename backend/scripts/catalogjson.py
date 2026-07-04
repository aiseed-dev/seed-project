# SPDX-License-Identifier: AGPL-3.0-only
"""静的配信用のカタログ JSON を生成する(docs/03)。

品目・品種マスタ・辞典記事・店舗カタログ(出品の基本情報)を JSON に
書き出す。在庫は含めない(必ず店側在庫API経由。ずれ防止)。
R2 へのアップロードは rclone 等で行う(例: rclone copy out/ r2:catalog)。
cron で定期実行するか、対象データの更新時に呼ぶ。
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import select  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402

from app.core.db import engine  # noqa: E402
from app.models import (  # noqa: E402
    Article,
    Category,
    Crop,
    Listing,
    Revision,
    Shop,
    Variety,
)


def build(out: Path) -> dict[str, int]:
    out.mkdir(parents=True, exist_ok=True)
    maker = sessionmaker(bind=engine())
    counts: dict[str, int] = {}
    with maker() as db:
        categories = [
            {"id": c.id, "slug": c.slug, "name": c.name, "sort": c.sort_order}
            for c in db.scalars(select(Category).order_by(Category.sort_order))
        ]
        crops = [
            {
                "id": str(c.id),
                "name": c.name,
                "kana": c.kana,
                "category_id": c.category_id,
                "summary": c.summary,
            }
            for c in db.scalars(select(Crop).order_by(Crop.sort_order))
        ]
        varieties = [
            {
                "id": str(v.id),
                "name": v.name,
                "kana": v.kana,
                "aliases": list(v.aliases),
                "category_id": v.category_id,
                "crop_id": str(v.crop_id) if v.crop_id else None,
                "seed_type": v.seed_type,
                "summary": v.summary,
            }
            for v in db.scalars(select(Variety).where(Variety.status == "approved"))
        ]
        articles = []
        rows = db.execute(
            select(Article, Revision).join(
                Revision, Article.current_revision_id == Revision.id
            )
        ).all()
        for article, revision in rows:
            articles.append(
                {
                    "variety_id": str(article.variety_id),
                    "content": dict(revision.content),
                    "updated_at": revision.created_at.isoformat(),
                }
            )
        shops = []
        for shop in db.scalars(select(Shop).where(Shop.is_active)):
            listings = [
                {
                    "id": str(listing.id),
                    "title": listing.title,
                    "variety_id": (
                        str(listing.variety_id) if listing.variety_id else None
                    ),
                    "price_yen": listing.price_yen,
                    "item_kind": listing.item_kind,
                    # 在庫はカタログJSONに含めない(店側在庫APIが正)
                }
                for listing in db.scalars(
                    select(Listing).where(
                        Listing.shop_id == shop.id,
                        Listing.status == "active",
                        Listing.moderation == "approved",
                    )
                )
            ]
            shops.append(
                {
                    "slug": shop.slug,
                    "name": shop.name,
                    "is_verified": shop.is_verified,
                    "listings": listings,
                }
            )

    for name, data in [
        ("categories", categories),
        ("crops", crops),
        ("varieties", varieties),
        ("articles", articles),
        ("shops", shops),
    ]:
        (out / f"{name}.json").write_text(
            json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8"
        )
        counts[name] = len(data)
    return counts


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="カタログJSONを生成する")
    parser.add_argument("-o", "--out", type=Path, default=Path("out/catalog"))
    args = parser.parse_args(argv)
    counts = build(args.out)
    print(" ".join(f"{k}={v}" for k, v in counts.items()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
