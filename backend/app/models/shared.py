# SPDX-License-Identifier: AGPL-3.0-only
"""shared スキーマ(ユーザー・分類・品目・品種・店舗)。"""

import datetime
import uuid

from sqlalchemy import Boolean, ForeignKey, Integer, Text, text
from sqlalchemy.dialects.postgresql import ARRAY, TIMESTAMP, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base

_now = text("now()")


class AppUser(Base):
    __tablename__ = "app_users"
    __table_args__ = {"schema": "shared"}

    id: Mapped[str] = mapped_column(Text, primary_key=True)  # PocketBase record id
    display_name: Mapped[str] = mapped_column(Text)
    region: Mapped[str | None] = mapped_column(Text)
    bio: Mapped[str | None] = mapped_column(Text)
    avatar_path: Mapped[str | None] = mapped_column(Text)
    role: Mapped[str] = mapped_column(Text, server_default=text("'user'"))
    is_suspended: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    created_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )
    updated_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )


class Category(Base):
    __tablename__ = "categories"
    __table_args__ = {"schema": "shared"}

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    slug: Mapped[str] = mapped_column(Text, unique=True)
    name: Mapped[str] = mapped_column(Text)
    icon: Mapped[str | None] = mapped_column(Text)
    sort_order: Mapped[int] = mapped_column(Integer, server_default=text("0"))


class Crop(Base):
    __tablename__ = "crops"
    __table_args__ = {"schema": "shared"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    name: Mapped[str] = mapped_column(Text, unique=True)
    kana: Mapped[str | None] = mapped_column(Text)
    category_id: Mapped[int] = mapped_column(ForeignKey("shared.categories.id"))
    scientific_name: Mapped[str | None] = mapped_column(Text)
    summary: Mapped[str | None] = mapped_column(Text)
    photo_path: Mapped[str | None] = mapped_column(Text)
    sort_order: Mapped[int] = mapped_column(Integer, server_default=text("0"))
    created_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )
    updated_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )


class Variety(Base):
    __tablename__ = "varieties"
    __table_args__ = {"schema": "shared"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    name: Mapped[str] = mapped_column(Text)
    kana: Mapped[str | None] = mapped_column(Text)
    aliases: Mapped[list[str]] = mapped_column(ARRAY(Text), server_default=text("'{}'"))
    category_id: Mapped[int] = mapped_column(ForeignKey("shared.categories.id"))
    crop_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("shared.crops.id"))
    crop_name: Mapped[str | None] = mapped_column(Text)
    scientific_name: Mapped[str | None] = mapped_column(Text)
    origin_region: Mapped[str | None] = mapped_column(Text)
    seed_type: Mapped[str] = mapped_column(Text, server_default=text("'unknown'"))
    is_registered_variety: Mapped[bool] = mapped_column(
        Boolean, server_default=text("false")
    )
    registration_note: Mapped[str | None] = mapped_column(Text)
    registration_checked_at: Mapped[datetime.datetime | None] = mapped_column(
        TIMESTAMP(timezone=True)
    )
    registration_checked_by: Mapped[str | None] = mapped_column(
        ForeignKey("shared.app_users.id")
    )
    summary: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(Text, server_default=text("'pending'"))
    proposed_by: Mapped[str | None] = mapped_column(ForeignKey("shared.app_users.id"))
    reviewed_by: Mapped[str | None] = mapped_column(ForeignKey("shared.app_users.id"))
    created_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )
    updated_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )


class Shop(Base):
    __tablename__ = "shops"
    __table_args__ = {"schema": "shared"}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    slug: Mapped[str] = mapped_column(Text, unique=True)
    code: Mapped[str] = mapped_column(Text, unique=True)
    name: Mapped[str] = mapped_column(Text)
    description: Mapped[str | None] = mapped_column(Text)
    website_url: Mapped[str | None] = mapped_column(Text)
    region: Mapped[str | None] = mapped_column(Text)
    logo_path: Mapped[str | None] = mapped_column(Text)
    contact_phone: Mapped[str | None] = mapped_column(Text)
    return_policy: Mapped[str | None] = mapped_column(Text)
    delivery_time: Mapped[str | None] = mapped_column(Text)
    is_verified: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))
    created_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )
    updated_at: Mapped[datetime.datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=_now
    )


class ShopMember(Base):
    __tablename__ = "shop_members"
    __table_args__ = {"schema": "shared"}

    shop_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("shared.shops.id", ondelete="CASCADE"), primary_key=True
    )
    user_id: Mapped[str] = mapped_column(
        ForeignKey("shared.app_users.id"), primary_key=True
    )
    role: Mapped[str] = mapped_column(Text, server_default=text("'staff'"))
    contact_label: Mapped[str | None] = mapped_column(Text)
