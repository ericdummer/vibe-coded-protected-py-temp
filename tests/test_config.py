"""
Test configuration management.
"""

import pytest
from pydantic import ValidationError

from app.core.config import Settings, get_settings


REQUIRED_ENV_VARS = (
    "POSTGRES_USER",
    "POSTGRES_PASSWORD",
    "POSTGRES_DB",
)


@pytest.fixture(autouse=True)
def _clear_settings_cache() -> None:
    """Ensure get_settings() cache does not leak between tests."""
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


@pytest.fixture
def _clean_env(monkeypatch: pytest.MonkeyPatch) -> None:
    """Isolate tests from local .env and process env noise."""
    monkeypatch.setenv("PYTHON_DOTENV_DISABLED", "1")
    monkeypatch.delenv("DEBUG", raising=False)
    monkeypatch.delenv("DATABASE_URL", raising=False)

    for key in REQUIRED_ENV_VARS:
        monkeypatch.delenv(key, raising=False)


def test_settings_loads_from_environment(monkeypatch: pytest.MonkeyPatch, _clean_env: None) -> None:
    monkeypatch.setenv("POSTGRES_USER", "test_user")
    monkeypatch.setenv("POSTGRES_PASSWORD", "test_pass")
    monkeypatch.setenv("POSTGRES_DB", "test_db")
    monkeypatch.setenv("DATABASE_URL", "postgresql://test_user:test_pass@localhost:5432/test_db")
    monkeypatch.setenv("DEBUG", "true")

    settings = Settings()

    assert settings.postgres_user == "test_user"
    assert settings.postgres_password == "test_pass"
    assert settings.postgres_db == "test_db"
    assert settings.debug is True


def test_settings_requires_postgres_fields(_clean_env: None) -> None:
    with pytest.raises(ValidationError):
        Settings()


def test_get_settings_is_cached(monkeypatch: pytest.MonkeyPatch, _clean_env: None) -> None:
    monkeypatch.setenv("POSTGRES_USER", "cached_user")
    monkeypatch.setenv("POSTGRES_PASSWORD", "cached_pass")
    monkeypatch.setenv("POSTGRES_DB", "cached_db")
    monkeypatch.setenv("DATABASE_URL", "postgresql://cached_user:cached_pass@localhost:5432/cached_db")

    first = get_settings()
    second = get_settings()

    assert first is second
