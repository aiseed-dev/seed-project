# SPDX-License-Identifier: AGPL-3.0-only
"""アプリ設定。環境変数(.env)で上書きできる。"""

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="seed_")

    database_url: str = "postgresql+psycopg://seed:seed@localhost:5432/seed"
    pocketbase_url: str = "http://localhost:8090"
    images_dir: Path = Path("./data/images")


@lru_cache
def settings() -> Settings:
    return Settings()
