"""
Test configuration management.
"""

from app.core.config import Settings, get_settings


def test_settings_from_defaults(monkeypatch):
    """
    Test that settings can be created with defaults.
    """
    monkeypatch.delenv("DEBUG", raising=False)
    get_settings.cache_clear()
    settings = Settings(database_url="postgresql://user:pass@localhost:5432/db")
    assert settings.app_name == "Vibe Coded Protected API"
    assert settings.debug is False
    assert settings.host == "0.0.0.0"
    assert settings.port == 8000


def test_settings_custom_values():
    """
    Test that settings can be customized.
    """
    settings = Settings(
        database_url="postgresql://custom:pass@localhost:5432/customdb",
        app_name="Custom App",
        debug=True,
        port=9000,
    )
    assert settings.app_name == "Custom App"
    assert settings.debug is True
    assert settings.port == 9000


def test_get_settings_returns_settings():
    """
    Test that get_settings returns a Settings instance.
    """
    settings = get_settings()
    assert isinstance(settings, Settings)
