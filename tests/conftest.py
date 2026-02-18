"""
Test configuration and fixtures.
"""

import pytest
from fastapi.testclient import TestClient
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

    return Settings(
        database_url="postgresql://testuser:testpass@localhost:5432/testdb",
        debug=True,
    )
