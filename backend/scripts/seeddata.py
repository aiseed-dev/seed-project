# SPDX-License-Identifier: AGPL-3.0-only
"""デモ用シードデータ(docs/08 Phase 8)。

伝統野菜30品種(承認済み)+出品50件+辞典記事10本+デモ店舗を投入する。
二重投入を避けるため、デモユーザーが既に居れば何もしない。
実行: python scripts/seeddata.py
"""

import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy.orm import Session, sessionmaker  # noqa: E402

from app.core.db import engine  # noqa: E402
from app.models import AppUser, Listing, Shop, ShopMember, Variety  # noqa: E402
from app.services.dictionary import approve_revision, submit_revision  # noqa: E402

rng = random.Random(2026)  # 再現可能に

USERS = [
    ("demo-taro", "種子 太郎", "徳島県"),
    ("demo-hanako", "山田 花子", "埼玉県"),
    ("demo-ichiro", "佐藤 一郎", "長野県"),
    ("demo-admin", "運営", None),
    ("demo-staff", "たねの森スタッフ", "埼玉県"),
]

# (品種名, かな, category_id, 種別, 来歴, 概要)
VARIETIES = [
    ("三浦大根", "みうらだいこん", 3, "fixed", "神奈川県", "煮物に向く白首大根。"),
    (
        "聖護院大根",
        "しょうごいんだいこん",
        3,
        "fixed",
        "京都府",
        "丸大根の代表。甘く煮崩れしにくい。",
    ),
    ("練馬大根", "ねりまだいこん", 3, "fixed", "東京都", "たくあん漬けの名品種。"),
    (
        "みやま小かぶ",
        "みやまこかぶ",
        3,
        "fixed",
        "東京都",
        "肉質緻密で甘い小かぶの定番。",
    ),
    ("天王寺かぶ", "てんのうじかぶ", 3, "native", "大阪府", "なにわの伝統野菜。"),
    ("金町こかぶ", "かなまちこかぶ", 3, "fixed", "東京都", "早生の小かぶ。"),
    ("真黒茄子", "しんくろなす", 1, "fixed", "埼玉県", "濃黒紫色の中長なす。"),
    ("民田茄子", "みんでんなす", 1, "native", "山形県", "小なす漬けの伝統品種。"),
    ("賀茂茄子", "かもなす", 1, "native", "京都府", "田楽で名高い丸なす。"),
    (
        "鷹峯とうがらし",
        "たかがみねとうがらし",
        1,
        "native",
        "京都府",
        "肉厚で甘い京の伝統とうがらし。",
    ),
    ("万願寺とうがらし", "まんがんじとうがらし", 1, "native", "京都府", "大型で甘い。"),
    (
        "伏見甘長とうがらし",
        "ふしみあまなが",
        1,
        "native",
        "京都府",
        "細長い甘とうがらし。",
    ),
    ("世界一トマト", "せかいいちとまと", 1, "fixed", "愛知県", "大玉の桃色トマト。"),
    (
        "ポンデローザトマト",
        "ぽんでろーざ",
        1,
        "fixed",
        "アメリカ",
        "明治期渡来の大玉種。",
    ),
    (
        "相模半白胡瓜",
        "さがみはんじろ",
        1,
        "fixed",
        "神奈川県",
        "半白の歯切れよい胡瓜。",
    ),
    ("加賀太胡瓜", "かがふとききゅうり", 1, "native", "石川県", "太く肉厚な加賀野菜。"),
    (
        "打木赤皮甘栗南瓜",
        "うつぎあかがわあまぐり",
        1,
        "native",
        "石川県",
        "鮮やかな赤皮の早生南瓜。",
    ),
    (
        "鹿ケ谷南瓜",
        "ししがたにかぼちゃ",
        1,
        "native",
        "京都府",
        "ひょうたん形の京南瓜。",
    ),
    ("小菊南瓜", "こぎくかぼちゃ", 1, "fixed", "日本", "菊座の小型南瓜。"),
    ("のらぼう菜", "のらぼうな", 2, "native", "東京都", "早春のとう立ち菜。甘く強健。"),
    ("山東菜", "さんとうさい", 2, "fixed", "中国", "漬け菜に向く半結球白菜。"),
    ("野崎白菜", "のざきはくさい", 2, "fixed", "愛知県", "日本の白菜育成の礎。"),
    ("大阪しろな", "おおさかしろな", 2, "native", "大阪府", "柔らかい煮菜。"),
    (
        "水前寺もやし",
        "すいぜんじもやし",
        2,
        "native",
        "熊本県",
        "湧水で育てる伝統もやし。",
    ),
    ("金時人参", "きんときにんじん", 3, "fixed", "香川県", "正月の紅い京人参。"),
    ("滝野川ごぼう", "たきのがわごぼう", 3, "fixed", "東京都", "長根ごぼうの代表。"),
    ("丹波黒大豆", "たんばくろだいず", 4, "native", "兵庫県", "正月の黒豆の最高峰。"),
    ("鞍掛豆", "くらかけまめ", 4, "native", "長野県", "浸し豆で人気の青大豆。"),
    (
        "借金なし大豆",
        "しゃっきんなしだいず",
        4,
        "fixed",
        "埼玉県",
        "多収で味の良い在来大豆。",
    ),
    (
        "八列とうもろこし",
        "はちれつとうもろこし",
        5,
        "native",
        "北海道",
        "明治期から続く硬粒種。",
    ),
]

ARTICLE = {
    "history": "江戸時代から栽培が続く伝統品種。産地の食文化とともに受け継がれてきた。",
    "cultivation": "蒔き時は春または初秋。間引きを丁寧に行い、乾燥に注意する。",
    "seed_saving": "母本を選抜し、交雑を避けるため同種の他品種と距離をとる。",
    "cooking": "煮物・漬物など郷土の料理に幅広く使われる。",
    "sources": "各県の伝統野菜資料・種苗店カタログ。",
}


def run(db: Session) -> str:
    if db.get(AppUser, "demo-taro") is not None:
        return "デモデータは投入済みです"

    for user_id, name, region in USERS:
        db.add(
            AppUser(
                id=user_id,
                display_name=name,
                region=region,
                role="admin" if user_id == "demo-admin" else "user",
            )
        )
    shop = Shop(
        slug="tanenomori-demo",
        code="TANE",
        name="たねの森(デモ)",
        region="埼玉県日高市",
        is_verified=True,
    )
    db.add(shop)
    db.flush()
    db.add(
        ShopMember(
            shop_id=shop.id,
            user_id="demo-staff",
            role="owner",
            contact_label="種苗部 田中",
        )
    )

    varieties: list[Variety] = []
    for name, kana, category_id, seed_type, origin, summary in VARIETIES:
        variety = Variety(
            name=name,
            kana=kana,
            category_id=category_id,
            seed_type=seed_type,
            origin_region=origin,
            summary=summary,
            status="approved",
            proposed_by="demo-taro",
            reviewed_by="demo-admin",
        )
        db.add(variety)
        varieties.append(variety)
    db.flush()

    # 辞典記事10本(提案→承認)
    for variety in varieties[:10]:
        revision = submit_revision(
            db,
            variety,
            "demo-hanako",
            {k: f"{variety.name}: {v}" for k, v in ARTICLE.items()},
            "デモ記事",
        )
        approve_revision(db, revision, "demo-admin")

    # 出品50件(個人40+店舗10)
    people = ["demo-taro", "demo-hanako", "demo-ichiro"]
    for index in range(50):
        variety = varieties[index % len(varieties)]
        is_shop = index >= 40
        listing_type = "sell" if is_shop else rng.choice(["exchange", "sell", "give"])
        db.add(
            Listing(
                user_id="demo-staff" if is_shop else people[index % 3],
                shop_id=shop.id if is_shop else None,
                variety_id=variety.id,
                variety_name_free=variety.name,
                category_id=variety.category_id,
                title=f"{variety.name}の種" + ("(自家採種)" if not is_shop else ""),
                description=variety.summary or "",
                listing_type=listing_type,
                price_yen=360 if listing_type == "sell" else None,
                desired_trade="在来種の葉物" if listing_type == "exchange" else None,
                quantity_note="小袋 約30粒",
                harvest_year=2025,
                is_self_saved=not is_shop,
                region=variety.origin_region,
                requires_seed_label=is_shop,
                label_seller_name=shop.name if is_shop else None,
                label_seller_address=shop.region if is_shop else None,
                label_production_area=variety.origin_region if is_shop else None,
                label_germination_rate="2026年6月現在 85%以上" if is_shop else None,
                no_warranty=not is_shop,
                non_registered_confirmed=True,
            )
        )
    db.commit()
    return f"投入完了: 品種{len(varieties)} 記事10 出品50 店舗1"


def main() -> int:
    maker = sessionmaker(bind=engine())
    with maker() as db:
        print(run(db))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
