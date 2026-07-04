# SPDX-License-Identifier: AGPL-3.0-only
"""辞典記事・リビジョンの入出力スキーマ(docs/03)。"""

import datetime
import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class ArticleOut(BaseModel):
    variety_id: uuid.UUID
    variety_name: str
    content: dict[str, str]  # {history, cultivation, seed_saving, cooking, sources}
    updated_at: datetime.datetime | None


class RevisionCreate(BaseModel):
    content: dict[str, str]
    edit_summary: str | None = Field(default=None, max_length=200)


class RevisionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    article_id: uuid.UUID
    author_id: str
    edit_summary: str | None
    status: str
    review_note: str | None
    created_at: datetime.datetime


class RevisionQueueEntry(BaseModel):
    revision: RevisionOut
    variety_name: str
    author_name: str


class RevisionDetailOut(BaseModel):
    revision: RevisionOut
    variety_name: str
    content: dict[str, str]
    diff: dict[str, list[dict[str, str]]]  # セクション → [{text, op}]


class RevisionPatch(BaseModel):
    action: Literal["approve", "reject"]
    review_note: str | None = None  # reject 時は必須


class VarietyPropose(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    category_id: int
    kana: str | None = None
    crop_name: str | None = None
    summary: str | None = None


class MeOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    display_name: str
    region: str | None
    bio: str | None
    role: str


class MePatch(BaseModel):
    display_name: str | None = Field(default=None, min_length=1, max_length=50)
    region: str | None = None
    bio: str | None = Field(default=None, max_length=500)
