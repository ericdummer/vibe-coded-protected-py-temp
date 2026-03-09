"""
Tests for the mock Google Maps Grounding Lite MCP server.

Covers:
- tools/list
- tools/call for search_places, lookup_weather (current, hourly, daily), compute_routes
- Error cases: missing auth, unknown method, unknown tool, missing required params
"""


API_KEY = "test-api-key"
MCP_URL = "/mcp"
HEADERS_JSON = {"Content-Type": "application/json"}
HEADERS_AUTH = {**HEADERS_JSON, "X-Goog-Api-Key": API_KEY}


def _rpc(method: str, params: dict | None = None, rpc_id: int = 1) -> dict:
    body: dict = {"jsonrpc": "2.0", "method": method, "id": rpc_id}
    if params is not None:
        body["params"] = params
    return body


# ---------------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------------


def test_missing_api_key_returns_error(client):
    """Missing X-Goog-Api-Key should return a JSON-RPC error (not HTTP 401)."""
    response = client.post(MCP_URL, json=_rpc("tools/list"), headers=HEADERS_JSON)
    assert response.status_code == 200
    data = response.json()
    assert data["error"] is not None
    assert data["error"]["code"] == -32000
    assert "X-Goog-Api-Key" in data["error"]["message"]


def test_empty_api_key_returns_error(client):
    """Empty X-Goog-Api-Key should be treated as missing."""
    response = client.post(
        MCP_URL,
        json=_rpc("tools/list"),
        headers={**HEADERS_JSON, "X-Goog-Api-Key": ""},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["error"] is not None


# ---------------------------------------------------------------------------
# tools/list
# ---------------------------------------------------------------------------


def test_tools_list_returns_three_tools(client):
    """tools/list should return exactly the 3 Grounding Lite tools."""
    response = client.post(MCP_URL, json=_rpc("tools/list"), headers=HEADERS_AUTH)
    assert response.status_code == 200
    data = response.json()
    assert data["error"] is None
    tools = data["result"]["tools"]
    assert len(tools) == 3
    names = {t["name"] for t in tools}
    assert names == {"search_places", "lookup_weather", "compute_routes"}


def test_tools_list_tool_has_required_fields(client):
    """Each tool definition must have name, description, and inputSchema."""
    response = client.post(MCP_URL, json=_rpc("tools/list"), headers=HEADERS_AUTH)
    tools = response.json()["result"]["tools"]
    for tool in tools:
        assert "name" in tool
        assert "description" in tool
        assert "inputSchema" in tool
        assert tool["inputSchema"]["type"] == "object"


# ---------------------------------------------------------------------------
# tools/call — search_places
# ---------------------------------------------------------------------------


def test_search_places_basic(client):
    """search_places with a text_query should return places and a summary."""
    response = client.post(
        MCP_URL,
        json=_rpc(
            "tools/call",
            {
                "name": "search_places",
                "arguments": {"textQuery": "coffee shops in New York"},
            },
        ),
        headers=HEADERS_AUTH,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["error"] is None
    result = data["result"]["result"]
    assert "places" in result
    assert "summary" in result
    assert len(result["places"]) > 0
    assert "coffee" in result["summary"].lower()


def test_search_places_with_location_bias(client):
    """search_places with locationBias should still return valid places."""
    response = client.post(
        MCP_URL,
        json=_rpc(
            "tools/call",
            {
                "name": "search_places",
                "arguments": {
                    "textQuery": "pizza restaurants",
                    "locationBias": {
                        "circle": {
                            "center": {"latitude": 40.7128, "longitude": -74.0060},
                            "radiusMeters": 5000,
                        }
                    },
                },
            },
        ),
        headers=HEADERS_AUTH,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["error"] is None
    places = data["result"]["result"]["places"]
    assert len(places) > 0
    # Coordinates should be near New York
    for place in places:
        assert "location" in place
        assert abs(place["location"]["latitude"] - 40.7128) < 1.0


def test_search_places_place_has_maps_links(client):
    """Each place should have googleMapsLinks with required URLs."""
    response = client.post(
        MCP_URL,
        json=_rpc(
            "tools/call",
            {"name": "search_places", "arguments": {"textQuery": "parks in Chicago"}},
        ),
        headers=HEADERS_AUTH,
    )
    places = response.json()["result"]["result"]["places"]
    for place in places:
        links = place["googleMapsLinks"]
        assert "placeUrl" in links
        assert "directionsUrl" in links


def test_search_places_missing_text_query_returns_error(client):
    """search_places without textQuery should return an invalid-params error."""
    response = client.post(
        MCP_URL,
        json=_rpc("tools/call", {"name": "search_places", "arguments": {}}),
        headers=HEADERS_AUTH,
    )
    data = response.json()
    assert data["error"] is not None
    assert data["error"]["code"] == -32602


# ---------------------------------------------------------------------------
# tools/call — lookup_weather
# ---------------------------------------------------------------------------


def test_lookup_weather_current_by_address(client):
    """lookup_weather with address only should return current conditions."""
    response = client.post(
        MCP_URL,
        json=_rpc(
            "tools/call",
            {
                "name": "lookup_weather",
                "arguments": {"location": {"address": "London, UK"}},
            },
        ),
        headers=HEADERS_AUTH,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["error"] is None
    result = data["result"]["result"]
    assert "currentConditions" in result
    assert "temperature" in result["currentConditions"]
    assert result["geocodedAddress"] == "London, UK"


def test_lookup_weather_imperial_units(client):
    """lookup_weather with IMPERIAL units should return FAHRENHEIT."""
    response = client.post(
        MCP_URL,
        json=_rpc(
            "tools/call",
            {
                "name": "lookup_weather",
                "arguments": {
                    "location": {"address": "New York, USA"},
                    "unitsSystem": "IMPERIAL",
                },
            },
        ),
        headers=HEADERS_AUTH,
    )
    result = response.json()["result"]["result"]
    assert result["currentConditions"]["temperature"]["unit"] == "FAHRENHEIT"


def test_lookup_weather_daily_forecast(client):
    """lookup_weather with date but no hour should return daily forecast."""
    response = client.post(
        MCP_URL,
        json=_rpc(
            "tools/call",
            {
                "name": "lookup_weather",
                "arguments": {
                    "location": {"address": "Paris, France"},
                    "date": {"year": 2026, "month": 6, "day": 15},
                },
            },
        ),
        headers=HEADERS_AUTH,
    )
    result = response.json()["result"]["result"]
    assert "dailyForecast" in result
    assert len(result["dailyForecast"]) == 7


def test_lookup_weather_hourly_forecast(client):
    """lookup_weather with date and hour should return hourly forecast."""
    response = client.post(
        MCP_URL,
        json=_rpc(
            "tools/call",
            {
                "name": "lookup_weather",
                "arguments": {
                    "location": {"address": "Tokyo, Japan"},
                    "date": {"year": 2026, "month": 3, "day": 10},
                    "hour": 14,
                },
            },
        ),
        headers=HEADERS_AUTH,
    )
    result = response.json()["result"]["result"]
    assert "hourlyForecast" in result
    assert result["hourlyForecast"][0]["hour"] == 14


def test_lookup_weather_by_lat_lng(client):
    """lookup_weather with latLng should geocode and return conditions."""
    response = client.post(
        MCP_URL,
        json=_rpc(
            "tools/call",
            {
                "name": "lookup_weather",
                "arguments": {
                    "location": {"latLng": {"latitude": 48.8566, "longitude": 2.3522}}
                },
            },
        ),
        headers=HEADERS_AUTH,
    )
    result = response.json()["result"]["result"]
    assert "currentConditions" in result
    assert "48.8566" in result["geocodedAddress"]


def test_lookup_weather_missing_location_returns_error(client):
    """lookup_weather without location should return invalid-params error."""
    response = client.post(
        MCP_URL,
        json=_rpc("tools/call", {"name": "lookup_weather", "arguments": {}}),
        headers=HEADERS_AUTH,
    )
    data = response.json()
    assert data["error"] is not None
    assert data["error"]["code"] == -32602


# ---------------------------------------------------------------------------
# tools/call — compute_routes
# ---------------------------------------------------------------------------


def test_compute_routes_drive(client):
    """compute_routes with DRIVE mode should return distance and duration."""
    response = client.post(
        MCP_URL,
        json=_rpc(
            "tools/call",
            {
                "name": "compute_routes",
                "arguments": {
                    "origin": {"address": "Eiffel Tower, Paris"},
                    "destination": {"address": "Louvre Museum, Paris"},
                    "travelMode": "DRIVE",
                },
            },
        ),
        headers=HEADERS_AUTH,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["error"] is None
    routes = data["result"]["result"]["routes"]
    assert len(routes) == 1
    assert routes[0]["distanceMeters"] > 0
    assert "seconds" in routes[0]["duration"]


def test_compute_routes_walk(client):
    """compute_routes with WALK mode should return shorter distance."""
    response = client.post(
        MCP_URL,
        json=_rpc(
            "tools/call",
            {
                "name": "compute_routes",
                "arguments": {
                    "origin": {"address": "Central Park, New York"},
                    "destination": {"placeId": "ChIJOwE_Id1w5EAR4Q27FkL6T_0"},
                    "travelMode": "WALK",
                },
            },
        ),
        headers=HEADERS_AUTH,
    )
    routes = response.json()["result"]["result"]["routes"]
    assert routes[0]["distanceMeters"] < 10000  # walking distance is shorter


def test_compute_routes_by_lat_lng(client):
    """compute_routes with latLng waypoints should succeed."""
    response = client.post(
        MCP_URL,
        json=_rpc(
            "tools/call",
            {
                "name": "compute_routes",
                "arguments": {
                    "origin": {"latLng": {"latitude": 37.7749, "longitude": -122.4194}},
                    "destination": {
                        "latLng": {"latitude": 37.3382, "longitude": -121.8863}
                    },
                },
            },
        ),
        headers=HEADERS_AUTH,
    )
    data = response.json()
    assert data["error"] is None
    assert len(data["result"]["result"]["routes"]) == 1


def test_compute_routes_missing_destination_returns_error(client):
    """compute_routes without destination should return invalid-params error."""
    response = client.post(
        MCP_URL,
        json=_rpc(
            "tools/call",
            {
                "name": "compute_routes",
                "arguments": {"origin": {"address": "Somewhere"}},
            },
        ),
        headers=HEADERS_AUTH,
    )
    data = response.json()
    assert data["error"] is not None
    assert data["error"]["code"] == -32602


# ---------------------------------------------------------------------------
# Error handling
# ---------------------------------------------------------------------------


def test_unknown_method_returns_method_not_found(client):
    """Calling an unknown JSON-RPC method should return -32601."""
    response = client.post(
        MCP_URL,
        json=_rpc("nonexistent/method"),
        headers=HEADERS_AUTH,
    )
    data = response.json()
    assert data["error"]["code"] == -32601


def test_unknown_tool_returns_invalid_params(client):
    """Calling tools/call with an unknown tool name should return -32602."""
    response = client.post(
        MCP_URL,
        json=_rpc("tools/call", {"name": "nonexistent_tool", "arguments": {}}),
        headers=HEADERS_AUTH,
    )
    data = response.json()
    assert data["error"]["code"] == -32602


def test_tools_call_without_params_returns_invalid_params(client):
    """tools/call without a params block should return -32602."""
    response = client.post(
        MCP_URL,
        json=_rpc("tools/call"),
        headers=HEADERS_AUTH,
    )
    data = response.json()
    assert data["error"]["code"] == -32602


def test_invalid_json_body_returns_parse_error(client):
    """Sending a non-JSON body should return a parse error."""
    response = client.post(
        MCP_URL,
        content=b"not json at all!!!",
        headers={**HEADERS_AUTH, "Content-Type": "application/json"},
    )
    data = response.json()
    assert data["error"]["code"] == -32700


def test_jsonrpc_id_is_echoed_back(client):
    """The JSON-RPC id in the request should be echoed in the response."""
    response = client.post(
        MCP_URL,
        json=_rpc("tools/list", rpc_id=42),
        headers=HEADERS_AUTH,
    )
    assert response.json()["id"] == 42
