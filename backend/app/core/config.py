# SPDX-License-Identifier: AGPL-3.0-only
"""アプリ設定。環境変数(.env)で上書きできる。"""

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="seed_")

    database_url: str = "postgresql+psycopg://seed:seed@localhost:5432/seed"
    pocketbase_url: str = "http://localhost:8090"
    pocketbase_admin_token: str = ""  # メール宛先の解決に使用(空なら送信スキップ)
    images_dir: Path = Path("./data/images")
    # メール: 既定は localhost の Stalwart へ直接。外部リレーは環境変数で切替
    smtp_host: str = "localhost"
    smtp_port: int = 25
    smtp_user: str = ""
    smtp_password: str = ""
    mail_from: str = "たねの森 <noreply@localhost>"
    request_expire_days: int = 7  # requested 放置の自動クローズ


@lru_cache
def settings() -> Settings:
    return Settings()
