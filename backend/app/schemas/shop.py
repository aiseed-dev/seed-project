# SPDX-License-Identifier: AGPL-3.0-only
"""店舗スタッフ API の入出力スキーマ(docs/03)。"""

import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class ShopOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    slug: str
    code: str
    name: str
    description: str | None
    website_url: str | None
    region: str | None
    contact_phone: str | None
    return_policy: str | None
    delivery_time: str | None
    is_verified: bool
    is_active: bool


class ShopPatch(BaseModel):
    description: str | None = None
    website_url: str | None = None
    region: str | None = None
    contact_phone: str | None = None
    return_policy: str | None = None
    delivery_time: str | None = None


class MemberOut(BaseModel):
    user_id: str
    display_name: str
    role: str
    contact_label: str | None


class ContactLabelPatch(BaseModel):
    contact_label: str = Field(min_length=1, max_length=50)


class BulkAction(BaseModel):
    ids: list[uuid.UUID] = Field(min_length=1)
    action: Literal["publish", "close", "price"]
    price_yen: int | None = Field(default=None, gt=0)


class ImportRowResult(BaseModel):
    row: int  # 1始まり(ヘッダ除く)
    status: Literal["created", "proposed", "error"]
    name: str
    detail: str | None = None
    listing_id: uuid.UUID | None = None


class ImportResult(BaseModel):
    created: int
    proposed: int
    errors: int
    rows: list[ImportRowResult]


class ShopStatsRow(BaseModel):
    listing_id: uuid.UUID
    title: str
    status: str
    request_count: int
