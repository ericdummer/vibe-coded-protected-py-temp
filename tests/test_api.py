"""
Test API endpoints.
"""


def test_health_check(client):
    """
    Test the health check endpoint returns 200 and correct response.
    """
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "message" in data


def test_root_endpoint(client):
    """
    Test the root endpoint returns welcome message.
    """
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    assert "Vibe Coded Protected API" in data["message"]


def test_docs_available(client):
    """
    Test that API documentation is available.
    """
    response = client.get("/docs")
    assert response.status_code == 200
