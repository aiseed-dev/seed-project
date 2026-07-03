# SPDX-License-Identifier: AGPL-3.0-only
"""出品 API(docs/03)。

種苗法対応のバリデーションはここで行う:
- 確認チェック必須(422 CONFIRMATION_REQUIRED)
- 登録品種ブロック(409 REGISTERED_VARIETY)
- 指定種苗の表示義務(422 SEED_LABEL_REQUIRED)
"""

import datetime
import uuid

from fastapi import APIRouter, Depends, Query, UploadFile
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.auth import require_user
from app.core.db import get_db
from app.core.errors import ApiError
from app.models import Category, Listing, ListingPhoto, Shop, ShopMember, Variety
from app.schemas.listings import ListingCreate, ListingOut, PhotoOut
from app.services import images
from app.services.variety import resolve_free_name

router = APIRouter(tags=["listings"])

MAX_PHOTOS = 4


@router.get("/listings")
def list_listings(
    category: str | None = None,
    type: str | None = Query(default=None, pattern="^(exchange|sell|give)$"),
    region: str | None = None,
    q: str | None = None,
    shop: str | None = None,
    cursor: datetime.datetime | None = None,
    limit: int = Query(default=20, ge=1, le=50),
    db: Session = Depends(get_db),
) -> dict[str, object]:
    stmt = (
        select(Listing)
        .options(selectinload(Listing.photos))
        .where(Listing.status == "active", Listing.moderation == "approved")
        .order_by(Listing.created_at.desc())
    )
    if category:
        stmt = stmt.join(Category, Listing.category_id == Category.id).where(
            Category.slug == category
        )
    if type:
        stmt = stmt.where(Listing.listing_type == type)
    if region:
        stmt = stmt.where(Listing.region == region)
    if q:
        pattern = f"%{q}%"
        stmt = stmt.where(
            Listing.title.ilike(pattern) | Listing.description.ilike(pattern)
        )
    if shop:
        stmt = stmt.join(Shop, Listing.shop_id == Shop.id).where(Shop.slug == shop)
    if cursor:
        stmt = stmt.where(Listing.created_at < cursor)
    rows = db.scalars(stmt.limit(limit)).all()
    next_cursor = rows[-1].created_at.isoformat() if len(rows) == limit else None
    return {
        "items": [ListingOut.model_validate(row) for row in rows],
        "next_cursor": next_cursor,
    }


@router.get("/listings/{listing_id}")
def get_listing(listing_id: uuid.UUID, db: Session = Depends(get_db)) -> ListingOut:
    listing = db.get(Listing, listing_id, options=[selectinload(Listing.photos)])
    if listing is None or listing.moderation == "removed":
        raise ApiError(404, "NOT_FOUND", "出品が見つかりません")
    return ListingOut.model_validate(listing)


def _validate_seed_label(payload: ListingCreate) -> None:
    """指定種苗の表示義務(種苗法22条)。種子は発芽率も必須。"""
    required = [
        payload.label_seller_name,
        payload.label_seller_address,
        payload.label_production_area,
    ]
    if payload.item_kind == "seed":
        required.append(payload.label_germination_rate)
    if not all(value and value.strip() for value in required):
        raise ApiError(
            422,
            "SEED_LABEL_REQUIRED",
            "指定種苗の表示(氏名・住所・生産地、種子は発芽率)が必要です",
        )


@router.post("/listings", status_code=201)
def create_listing(
    payload: ListingCreate,
    user_id: str = Depends(require_user),
    db: Session = Depends(get_db),
) -> ListingOut:
    # 種苗法対応: 「登録品種ではない」確認は必須。緩和・スキップ禁止
    if not payload.non_registered_confirmed:
        raise ApiError(
            422,
            "CONFIRMATION_REQUIRED",
            "登録品種でないことの確認チェックが必要です",
        )

    if db.get(Category, payload.category_id) is None:
        raise ApiError(422, "CATEGORY_INVALID", "分類が不正です")

    variety_id: uuid.UUID | None = None
    variety_name_free = (payload.variety_name_free or "").strip() or None
    if payload.variety_id is not None:
        variety = db.get(Variety, payload.variety_id)
        if variety is None:
            raise ApiError(404, "NOT_FOUND", "品種が見つかりません")
        if variety.is_registered_variety:
            raise ApiError(
                409,
                "REGISTERED_VARIETY",
                f"「{variety.name}」は登録品種のため出品できません",
            )
        variety_id = variety.id
    elif variety_name_free is not None:
        # 自由入力 → 品種マスタへの pending 提案を自動生成(既存名は再利用)
        variety = resolve_free_name(db, variety_name_free, payload.category_id, user_id)
        variety_id = variety.id
    else:
        raise ApiError(422, "VARIETY_REQUIRED", "品種を選ぶか品種名を入力してください")

    if payload.requires_seed_label:
        _validate_seed_label(payload)

    # 生産物×郵送は食品表示が必須(docs/11。加工品・許可要食品は対象外)
    if payload.item_kind == "produce" and payload.delivery_method == "mail":
        food = [
            payload.food_name,
            payload.food_origin,
            payload.food_producer,
            payload.food_harvest_date,
            payload.food_storage,
        ]
        if not all(food):
            raise ApiError(
                422,
                "FOOD_LABEL_REQUIRED",
                "食品表示(名称・原産地・生産者・収穫日・保存方法)が必要です",
            )

    # 郵送で業として売る事業者は特商法表示(店舗プロフィールから束ねる)
    if payload.requires_tokushoho:
        member = db.scalars(
            select(ShopMember).where(ShopMember.user_id == user_id)
        ).first()
        shop = db.get(Shop, member.shop_id) if member else None
        complete = shop is not None and all(
            [shop.region, shop.contact_phone, shop.return_policy, shop.delivery_time]
        )
        if not complete:
            raise ApiError(
                422,
                "TOKUSHOHO_REQUIRED",
                "特商法表示の項目(住所・連絡先・返品方針・引き渡し時期)を"
                "店舗プロフィールに設定してください",
            )

    if payload.listing_type == "sell" and payload.price_yen is None:
        raise ApiError(422, "PRICE_REQUIRED", "販売価格を入力してください")

    listing = Listing(
        user_id=user_id,
        variety_id=variety_id,
        variety_name_free=variety_name_free,
        category_id=payload.category_id,
        title=payload.title,
        description=payload.description,
        item_kind=payload.item_kind,
        listing_type=payload.listing_type,
        price_yen=payload.price_yen if payload.listing_type == "sell" else None,
        desired_trade=payload.desired_trade,
        quantity_note=payload.quantity_note,
        harvest_year=payload.harvest_year,
        is_self_saved=payload.is_self_saved,
        region=payload.region,
        cultivation_note=payload.cultivation_note,
        delivery_method=payload.delivery_method,
        payment_default=payload.payment_default,
        requires_seed_label=payload.requires_seed_label,
        label_seller_name=payload.label_seller_name,
        label_seller_address=payload.label_seller_address,
        label_production_area=payload.label_production_area,
        label_germination_rate=payload.label_germination_rate,
        label_seed_treatment=payload.label_seed_treatment,
        food_name=payload.food_name,
        food_origin=payload.food_origin,
        food_producer=payload.food_producer,
        food_harvest_date=payload.food_harvest_date,
        food_storage=payload.food_storage,
        requires_tokushoho=payload.requires_tokushoho,
        # 個人の家庭採種品は既定で無保証表示(業者品との区別)
        no_warranty=(
            payload.no_warranty
            if payload.no_warranty is not None
            else not payload.requires_seed_label
        ),
        non_registered_confirmed=True,
    )
    db.add(listing)
    db.commit()
    db.refresh(listing)
    return ListingOut.model_validate(listing)


def _own_listing(db: Session, listing_id: uuid.UUID, user_id: str) -> Listing:
    listing = db.get(Listing, listing_id)
    if listing is None:
        raise ApiError(404, "NOT_FOUND", "出品が見つかりません")
    if listing.user_id != user_id:
        raise ApiError(403, "NOT_OWNER", "本人のみ操作できます")
    return listing


@router.post("/listings/{listing_id}/photos", status_code=201)
async def upload_photos(
    listing_id: uuid.UUID,
    files: list[UploadFile],
    user_id: str = Depends(require_user),
    db: Session = Depends(get_db),
) -> list[PhotoOut]:
    listing = _own_listing(db, listing_id, user_id)
    current = db.scalars(
        select(ListingPhoto).where(ListingPhoto.listing_id == listing.id)
    ).all()
    if len(current) + len(files) > MAX_PHOTOS:
        raise ApiError(422, "PHOTO_LIMIT", f"写真は最大{MAX_PHOTOS}枚までです")

    created: list[ListingPhoto] = []
    for offset, file in enumerate(files):
        data = await file.read()
        relative = images.save_listing_photo(listing.id, data)
        photo = ListingPhoto(
            listing_id=listing.id,
            path=relative,
            sort_order=len(current) + offset,
        )
        db.add(photo)
        created.append(photo)
    db.commit()
    return [PhotoOut.model_validate(photo) for photo in created]


@router.delete("/photos/{photo_id}", status_code=204)
def delete_photo(
    photo_id: uuid.UUID,
    user_id: str = Depends(require_user),
    db: Session = Depends(get_db),
) -> None:
    photo = db.get(ListingPhoto, photo_id)
    if photo is None:
        raise ApiError(404, "NOT_FOUND", "写真が見つかりません")
    _own_listing(db, photo.listing_id, user_id)
    images.delete_photo_file(photo.path)
    db.delete(photo)
    db.commit()
