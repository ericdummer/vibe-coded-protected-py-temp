import os
from typing import Any
from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env",),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "Vibe Coded Protected API"
    debug: bool = False
    host: str = "0.0.0.0"
    port: int = 8000
    database_url: str | None = None
    db_host: str | None = None
    db_port: int = 5432
    db_name: str | None = None
    db_user: str | None = None
    aws_region: str = "us-east-2"
    db_iam_auth: bool = False
    postgres_user: str | None = None
    postgres_password: str | None = None
    postgres_db: str | None = None

    def __init__(self, **values: Any) -> None:
        if os.getenv("PYTHON_DOTENV_DISABLED") == "1" and "_env_file" not in values:
            values["_env_file"] = None
        super().__init__(**values)


@lru_cache
def get_settings() -> Settings:
    return Settings()
