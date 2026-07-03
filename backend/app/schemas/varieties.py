# SPDX-License-Identifier: AGPL-3.0-only
"""品種マスタの出力スキーマ。"""

import uuid

from pydantic import BaseModel, ConfigDict


class VarietyOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    kana: str | None
    aliases: list[str]
    category_id: int
    crop_id: uuid.UUID | None
    crop_name: str | None
    seed_type: str
    summary: str | None
    status: str
