# SPDX-License-Identifier: AGPL-3.0-only
"""exchange スキーマ(出品・カート・申込み・メッセージ・評価・通報)。"""

import datetime
import uuid

from sqlalchemy import Boolean, Date, ForeignKey, Integer, Text, text
from sqlalchemy.dialects.postgresql import TIMESTAMP, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base

_now = text("now()")


class Listing(Base):
    __tablename__ = "listings"
    __table_args__ = {"schema": "exchange"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[str] = mapped_column(ForeignKey("shared.app_users.id"))
    shop_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("shared.shops.id"))
    variety_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("shared.varieties.id")
    )
    variety_name_free: Mapped[str | None] = mapped_column(Text)
    category_id: Mapped[int] = mapped_column(ForeignKey("shared.categories.id"))
    title: Mapped[str] = mapped_column(Text)
    description: Mapped[str] = mapped_column(Text, server_default=text("''"))
    item_kind: Mapped[str] = mapped_column(Text, server_default=text("'seed'"))
    listing_type: Mapped[str] = mapped_column(Text)
    price_yen: Mapped[int | None] = mapped_column(Integer)
    desired_trade: Mapped[str | None] = mapped_column(Text)
    quantity_note: Mapped[str | None] = mapped_column(Text)
    harvest_year: Mapped[int | None] = mapped_column(Integer)
    is_self_saved: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    region: Mapped[str | None] = mapped_column(Text)
    cultivation_note: Mapped[str | None] = mapped_column(Text)
    delivery_method: Mapped[str] = mapped_column(Text, server_default=text("'mail'"))
    payment_default: Mapped[str] = mapped_column(Text, server_default=text("'later'"))
    food_name: Mapped[str | None] = mapped_column(Text)
    food_origin: Mapped[str | None] = mapped_column(Text)
    food_producer: Mapped[str | None] = mapped_column(Text)
    food_harvest_date: Mapped[datetime.date | None] = mapped_column(Date)
    food_storage: Mapped[str | None] = mapped_column(Text)
    requires_tokushoho: Mapped[bool] = mapped_column(
        Boolean, server_default=text("false")
    )
    no_warranty: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))
    requires_seed_label: Mapped[bool] = mapped_column(
        Boolean, server_default=text("false")
    )
    label_seller_name: Mapped[str | None] = mapped_column(Text)
    label_seller_address: Mapped[str | None] = mapped_column(Text)
    label_production_area: Mapped[str | None] = mapped_column(Text)
    label_germination_rate: Mapped[str | None] = mapped_column(Text)
    label_seed_treatment: Mapped[str | None] = mapped_column(Text)
    non_registered_confirmed: Mapped[bool] = mapped_column(Boolean)
    status: Mapped[str] = mapped_column(Text, server_default=text("'active'"))
    moderation: Mapped[str] = mapped_column(Text, server_default=text("'approved'"))
    created_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )
    updated_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )

    photos: Mapped[list["ListingPhoto"]] = relationship(
        back_populates="listing", order_by="ListingPhoto.sort_order"
    )


class ListingPhoto(Base):
    __tablename__ = "listing_photos"
    __table_args__ = {"schema": "exchange"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    listing_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("exchange.listings.id", ondelete="CASCADE")
    )
    path: Mapped[str] = mapped_column(Text)
    sort_order: Mapped[int] = mapped_column(Integer, server_default=text("0"))

    listing: Mapped[Listing] = relationship(back_populates="photos")


class CartItem(Base):
    __tablename__ = "cart_items"
    __table_args__ = {"schema": "exchange"}

    user_id: Mapped[str] = mapped_column(
        ForeignKey("shared.app_users.id"), primary_key=True
    )
    listing_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("exchange.listings.id", ondelete="CASCADE"), primary_key=True
    )
    quantity: Mapped[int] = mapped_column(Integer, server_default=text("1"))
    added_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )


class Request(Base):
    __tablename__ = "requests"
    __table_args__ = {"schema": "exchange"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    requester_id: Mapped[str] = mapped_column(ForeignKey("shared.app_users.id"))
    provider_user_id: Mapped[str | None] = mapped_column(
        ForeignKey("shared.app_users.id")
    )
    provider_shop_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("shared.shops.id")
    )
    request_no: Mapped[str] = mapped_column(Text, unique=True)
    request_year: Mapped[int | None] = mapped_column(Integer)
    request_seq: Mapped[int | None] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(Text, server_default=text("'requested'"))
    note: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )
    accepted_at: Mapped[datetime.datetime | None] = mapped_column(
        TIMESTAMP(timezone=True)
    )
    accepted_by: Mapped[str | None] = mapped_column(ForeignKey("shared.app_users.id"))
    completed_at: Mapped[datetime.datetime | None] = mapped_column(
        TIMESTAMP(timezone=True)
    )
    updated_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )


class RequestItem(Base):
    __tablename__ = "request_items"
    __table_args__ = {"schema": "exchange"}

    request_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("exchange.requests.id", ondelete="CASCADE"), primary_key=True
    )
    listing_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("exchange.listings.id"), primary_key=True
    )
    quantity: Mapped[int] = mapped_column(Integer, server_default=text("1"))


class Message(Base):
    __tablename__ = "messages"
    __table_args__ = {"schema": "exchange"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    request_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("exchange.requests.id", ondelete="CASCADE")
    )
    sender_id: Mapped[str] = mapped_column(ForeignKey("shared.app_users.id"))
    body: Mapped[str] = mapped_column(Text)
    sent_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )
    read_at: Mapped[datetime.datetime | None] = mapped_column(TIMESTAMP(timezone=True))


class Review(Base):
    __tablename__ = "reviews"
    __table_args__ = {"schema": "exchange"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    request_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("exchange.requests.id"))
    reviewer_id: Mapped[str] = mapped_column(ForeignKey("shared.app_users.id"))
    reviewee_id: Mapped[str] = mapped_column(ForeignKey("shared.app_users.id"))
    score: Mapped[int] = mapped_column(Integer)
    comment: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )


class Report(Base):
    __tablename__ = "reports"
    __table_args__ = {"schema": "exchange"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    reporter_id: Mapped[str] = mapped_column(ForeignKey("shared.app_users.id"))
    target_type: Mapped[str] = mapped_column(Text)
    target_id: Mapped[str] = mapped_column(Text)
    reason: Mapped[str] = mapped_column(Text)
    detail: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(Text, server_default=text("'open'"))
    handled_by: Mapped[str | None] = mapped_column(ForeignKey("shared.app_users.id"))
    created_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )
