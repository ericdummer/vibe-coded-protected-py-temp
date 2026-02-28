"""
Test configuration and fixtures.
"""

import os

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

from app.main import app


@pytest.fixture
def client():
    """
    Create a test client for the FastAPI application.
    """
    return TestClient(app)


@pytest.fixture
def test_settings():
    """
    Override settings for testing.
    """
    from app.core.config import Settings

    postgres_user = os.getenv("POSTGRES_USER")
    postgres_password = os.getenv("POSTGRES_PASSWORD")
    postgres_db = os.getenv("POSTGRES_DB")

    return Settings(
        database_url=os.getenv(
            "DATABASE_URL",
            "sqlite:///./test.db",
        ),
        debug=True,
        postgres_user=postgres_user,
        postgres_password=postgres_password,
        postgres_db=postgres_db,
    )
