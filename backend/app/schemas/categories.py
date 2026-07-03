# SPDX-License-Identifier: AGPL-3.0-only
"""分類の出力スキーマ。"""

from pydantic import BaseModel, ConfigDict


class CategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    slug: str
    name: str
    icon: str | None
    sort_order: int
