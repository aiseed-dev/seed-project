# SPDX-License-Identifier: AGPL-3.0-only
"""出品の入出力スキーマ(docs/03)。"""

import datetime
import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class ListingCreate(BaseModel):
    variety_id: uuid.UUID | None = None
    variety_name_free: str | None = Field(default=None, max_length=100)
    category_id: int
    title: str = Field(min_length=1, max_length=100)
    description: str = ""
    item_kind: Literal["seed", "seedling", "produce"] = "seed"
    listing_type: Literal["exchange", "sell", "give"]
    price_yen: int | None = Field(default=None, gt=0)
    desired_trade: str | None = None
    quantity_note: str | None = None
    harvest_year: int | None = None
    is_self_saved: bool = False
    region: str | None = None
    cultivation_note: str | None = None
    delivery_method: Literal["direct", "mail"] = "mail"
    payment_default: Literal["later", "prepay", "cod"] = "later"
    # 指定種苗の表示義務(種苗法22条)
    requires_seed_label: bool = False
    label_seller_name: str | None = None
    label_seller_address: str | None = None
    label_production_area: str | None = None
    label_germination_rate: str | None = None
    label_seed_treatment: str | None = None
    # 生産物(生鮮野菜)の郵送時の食品表示(docs/11)
    food_name: str | None = None
    food_origin: str | None = None
    food_producer: str | None = None
    food_harvest_date: datetime.date | None = None
    food_storage: str | None = None
    # 特商法表示(郵送で業として売る事業者)
    requires_tokushoho: bool = False
    # 個人品の性質表示。未指定なら業者品(requires_seed_label)以外は true
    no_warranty: bool | None = None
    # 種苗法対応: 「登録品種ではない」確認チェック
    non_registered_confirmed: bool = False


class PhotoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    path: str
    sort_order: int


class ListingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: str
    shop_id: uuid.UUID | None
    variety_id: uuid.UUID | None
    variety_name_free: str | None
    category_id: int
    title: str
    description: str
    item_kind: str
    listing_type: str
    price_yen: int | None
    desired_trade: str | None
    quantity_note: str | None
    harvest_year: int | None
    is_self_saved: bool
    region: str | None
    cultivation_note: str | None
    delivery_method: str
    payment_default: str
    requires_seed_label: bool
    label_seller_name: str | None
    label_seller_address: str | None
    label_production_area: str | None
    label_germination_rate: str | None
    label_seed_treatment: str | None
    food_name: str | None
    food_origin: str | None
    food_producer: str | None
    food_harvest_date: datetime.date | None
    food_storage: str | None
    requires_tokushoho: bool
    no_warranty: bool
    status: str
    created_at: datetime.datetime
    photos: list[PhotoOut] = []
