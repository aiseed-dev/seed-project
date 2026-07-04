# SPDX-License-Identifier: AGPL-3.0-only
"""カート API(docs/03)。提供者ごとにグループ化して返す。"""

import uuid

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.auth import require_user
from app.core.db import get_db
from app.core.errors import ApiError
from app.models import AppUser, CartItem, Listing, Shop
from app.schemas.requests import CartGroupOut, CartItemOut, CartPut, ProviderOut

router = APIRouter(tags=["cart"])


def cart_groups(db: Session, user_id: str) -> list[CartGroupOut]:
    rows = db.execute(
        select(CartItem, Listing)
        .join(Listing, CartItem.listing_id == Listing.id)
        .where(CartItem.user_id == user_id)
        .order_by(CartItem.added_at)
    ).all()

    grouped: dict[tuple[str, str], list[tuple[CartItem, Listing]]] = {}
    for item, listing in rows:
        key = (
            ("shop", str(listing.shop_id))
            if listing.shop_id
            else ("user", listing.user_id)
        )
        grouped.setdefault(key, []).append((item, listing))

    groups: list[CartGroupOut] = []
    for (kind, provider_id), members in grouped.items():
        if kind == "shop":
            shop = db.get(Shop, uuid.UUID(provider_id))
            provider = ProviderOut(
                kind="shop",
                id=provider_id,
                name=shop.name if shop else "店舗",
                is_verified=bool(shop and shop.is_verified),
            )
        else:
            user = db.get(AppUser, provider_id)
            provider = ProviderOut(
                kind="user",
                id=provider_id,
                name=user.display_name if user else "ユーザー",
            )
        items = [
            CartItemOut(
                listing_id=listing.id,
                title=listing.title,
                listing_type=listing.listing_type,
                price_yen=listing.price_yen,
                quantity=item.quantity,
                status=listing.status,
            )
            for item, listing in members
        ]
        sell_total = sum(
            (listing.price_yen or 0) * item.quantity
            for item, listing in members
            if listing.listing_type == "sell"
        )
        has_sell = any(listing.listing_type == "sell" for _, listing in members)
        groups.append(
            CartGroupOut(
                provider=provider,
                items=items,
                subtotal_yen=sell_total if has_sell else None,
            )
        )
    return groups


@router.get("/cart")
def get_cart(
    user_id: str = Depends(require_user), db: Session = Depends(get_db)
) -> list[CartGroupOut]:
    return cart_groups(db, user_id)


@router.put("/cart/items/{listing_id}")
def put_cart_item(
    listing_id: uuid.UUID,
    payload: CartPut,
    user_id: str = Depends(require_user),
    db: Session = Depends(get_db),
) -> dict[str, int]:
    listing = db.get(Listing, listing_id)
    if listing is None or listing.moderation != "approved":
        raise ApiError(404, "NOT_FOUND", "出品が見つかりません")
    if listing.status != "active":
        raise ApiError(409, "NOT_AVAILABLE", "取引中または終了した出品です")
    item = db.get(CartItem, (user_id, listing_id))
    if item is None:
        item = CartItem(user_id=user_id, listing_id=listing_id)
        db.add(item)
    item.quantity = payload.quantity
    db.commit()
    return {"quantity": item.quantity}


@router.delete("/cart/items/{listing_id}", status_code=204)
def delete_cart_item(
    listing_id: uuid.UUID,
    user_id: str = Depends(require_user),
    db: Session = Depends(get_db),
) -> None:
    item = db.get(CartItem, (user_id, listing_id))
    if item is None:
        raise ApiError(404, "NOT_FOUND", "カートにありません")
    db.delete(item)
    db.commit()
