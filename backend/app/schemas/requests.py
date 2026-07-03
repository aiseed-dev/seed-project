# SPDX-License-Identifier: AGPL-3.0-only
"""カート・申込み・メッセージ・評価・通報の入出力スキーマ(docs/03)。"""

import datetime
import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class CartPut(BaseModel):
    quantity: int = Field(ge=1)


class CartItemOut(BaseModel):
    listing_id: uuid.UUID
    title: str
    listing_type: str
    price_yen: int | None
    quantity: int
    status: str  # active 以外は「入手できなくなりました」表示


class ProviderOut(BaseModel):
    kind: Literal["user", "shop"]
    id: str
    name: str
    is_verified: bool = False


class CartGroupOut(BaseModel):
    provider: ProviderOut
    items: list[CartItemOut]
    subtotal_yen: int | None  # 販売品があるグループのみ(送料別)


class RequestCreate(BaseModel):
    provider_kind: Literal["user", "shop"]
    provider_id: str
    note: str | None = None


class RequestItemOut(BaseModel):
    listing_id: uuid.UUID
    title: str
    listing_type: str
    price_yen: int | None
    quantity: int


class RequestOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    request_no: str
    requester_id: str
    provider_user_id: str | None
    provider_shop_id: uuid.UUID | None
    status: str
    note: str | None
    created_at: datetime.datetime
    accepted_at: datetime.datetime | None
    completed_at: datetime.datetime | None


class RequestDetailOut(RequestOut):
    items: list[RequestItemOut] = []


class RequestListEntry(BaseModel):
    request: RequestOut
    role: Literal["requester", "provider"]
    item_count: int
    last_message: str | None


class RequestPatch(BaseModel):
    status: Literal["accepted", "declined", "cancelled", "completed"]


class MessageCreate(BaseModel):
    body: str = Field(min_length=1, max_length=2000)


class MessageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    sender_id: str
    body: str
    sent_at: datetime.datetime
    read_at: datetime.datetime | None


class ReviewCreate(BaseModel):
    score: int = Field(ge=1, le=5)
    comment: str | None = None


class ReviewOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    request_id: uuid.UUID
    reviewer_id: str
    reviewee_id: str
    score: int
    comment: str | None


class ReportCreate(BaseModel):
    target_type: Literal["listing", "message", "user", "variety", "revision", "request"]
    target_id: str
    reason: str = Field(min_length=1, max_length=100)
    detail: str | None = None
