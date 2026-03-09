"""
Mock Google Maps Grounding Lite MCP server endpoint.

Implements the JSON-RPC 2.0 protocol at POST /mcp, mirroring:
https://developers.google.com/maps/ai/grounding-lite

Supported methods:
- tools/list   — return the three available Grounding Lite tool definitions
- tools/call   — dispatch to search_places, lookup_weather, or compute_routes
"""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Header, Request
from pydantic import ValidationError

from app.api.mcp_mock_data import (
    build_compute_routes_response,
    build_lookup_weather_response,
    build_search_places_response,
)
from app.models.mcp_models import (
    ComputeRoutesRequest,
    JsonRpcError,
    JsonRpcRequest,
    JsonRpcResponse,
    LookupWeatherRequest,
    SearchPlacesRequest,
    ToolDefinition,
    ToolsListResult,
)

router = APIRouter()

# ---------------------------------------------------------------------------
# Tool definitions (mirrors the real Grounding Lite tool list)
# ---------------------------------------------------------------------------

_TOOLS: list[ToolDefinition] = [
    ToolDefinition(
        name="search_places",
        description=(
            "Call this tool when the user's request is to find places, businesses, "
            "addresses, locations, points of interest, or any other Google Maps related search."
        ),
        inputSchema={
            "type": "object",
            "required": ["textQuery"],
            "properties": {
                "textQuery": {
                    "type": "string",
                    "description": "The primary search query.",
                },
                "languageCode": {
                    "type": "string",
                    "description": "ISO 639-1 language code for summary language.",
                },
                "regionCode": {
                    "type": "string",
                    "description": "ISO 3166-1 alpha-2 country code.",
                },
                "pageSize": {
                    "type": "integer",
                    "description": "Maximum number of places to return.",
                },
                "pageToken": {
                    "type": "string",
                    "description": "Page token from a previous call.",
                },
                "locationBias": {
                    "type": "object",
                    "description": "Optional circle to bias results.",
                    "properties": {
                        "circle": {
                            "type": "object",
                            "properties": {
                                "center": {
                                    "type": "object",
                                    "properties": {
                                        "latitude": {"type": "number"},
                                        "longitude": {"type": "number"},
                                    },
                                    "required": ["latitude", "longitude"],
                                },
                                "radiusMeters": {"type": "number"},
                            },
                            "required": ["center"],
                        }
                    },
                },
            },
        },
    ),
    ToolDefinition(
        name="lookup_weather",
        description=(
            "Retrieves comprehensive weather data including current conditions, "
            "hourly, and daily forecasts."
        ),
        inputSchema={
            "type": "object",
            "required": ["location"],
            "properties": {
                "location": {
                    "type": "object",
                    "description": "Location (one of: latLng, placeId, address).",
                    "properties": {
                        "latLng": {
                            "type": "object",
                            "properties": {
                                "latitude": {"type": "number"},
                                "longitude": {"type": "number"},
                            },
                        },
                        "placeId": {"type": "string"},
                        "address": {"type": "string"},
                    },
                },
                "unitsSystem": {
                    "type": "string",
                    "enum": ["METRIC", "IMPERIAL"],
                    "description": "Unit system for returned values.",
                },
                "date": {
                    "type": "object",
                    "description": "Date for forecast (year, month, day).",
                    "properties": {
                        "year": {"type": "integer"},
                        "month": {"type": "integer"},
                        "day": {"type": "integer"},
                    },
                },
                "hour": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 23,
                    "description": "Hour (0-23) for hourly forecast.",
                },
            },
        },
    ),
    ToolDefinition(
        name="compute_routes",
        description=(
            "Computes a travel route between a specified origin and destination. "
            "Supported travel modes: DRIVE (default), WALK."
        ),
        inputSchema={
            "type": "object",
            "required": ["origin", "destination"],
            "properties": {
                "origin": {
                    "type": "object",
                    "description": "Origin waypoint (one of: address, latLng, placeId).",
                    "properties": {
                        "address": {"type": "string"},
                        "latLng": {
                            "type": "object",
                            "properties": {
                                "latitude": {"type": "number"},
                                "longitude": {"type": "number"},
                            },
                        },
                        "placeId": {"type": "string"},
                    },
                },
                "destination": {
                    "type": "object",
                    "description": "Destination waypoint (one of: address, latLng, placeId).",
                    "properties": {
                        "address": {"type": "string"},
                        "latLng": {
                            "type": "object",
                            "properties": {
                                "latitude": {"type": "number"},
                                "longitude": {"type": "number"},
                            },
                        },
                        "placeId": {"type": "string"},
                    },
                },
                "travelMode": {
                    "type": "string",
                    "enum": ["DRIVE", "WALK"],
                    "description": "Travel mode.",
                },
            },
        },
    ),
]

_TOOL_MAP = {t.name: t for t in _TOOLS}

# ---------------------------------------------------------------------------
# JSON-RPC helpers
# ---------------------------------------------------------------------------


def _ok(request_id: Any, result: Any) -> JsonRpcResponse:
    return JsonRpcResponse(id=request_id, result=result)


def _err(request_id: Any, code: int, message: str) -> JsonRpcResponse:
    return JsonRpcResponse(
        id=request_id, error=JsonRpcError(code=code, message=message)
    )


# Standard JSON-RPC 2.0 error codes
_PARSE_ERROR = -32700
_INVALID_REQUEST = -32600
_METHOD_NOT_FOUND = -32601
_INVALID_PARAMS = -32602
_INTERNAL_ERROR = -32603

# Application-level codes
_UNAUTHENTICATED = -32000

# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------


def _handle_tools_list() -> dict[str, Any]:
    return ToolsListResult(tools=_TOOLS).model_dump()


def _handle_tools_call(params: dict[str, Any]) -> dict[str, Any]:
    tool_name: str = params.get("name", "")
    arguments: dict[str, Any] = params.get("arguments") or {}

    if tool_name not in _TOOL_MAP:
        raise ValueError(f"Unknown tool: {tool_name}")

    if tool_name == "search_places":
        req = SearchPlacesRequest(**arguments)
        content = build_search_places_response(req)
    elif tool_name == "lookup_weather":
        req = LookupWeatherRequest(**arguments)
        content = build_lookup_weather_response(req)
    elif tool_name == "compute_routes":
        req = ComputeRoutesRequest(**arguments)
        content = build_compute_routes_response(req)
    else:
        raise ValueError(f"Unhandled tool: {tool_name}")  # pragma: no cover

    return {"content": [{"type": "text", "text": str(content)}], "result": content}


# ---------------------------------------------------------------------------
# Main endpoint
# ---------------------------------------------------------------------------


@router.post(
    "",
    response_model=JsonRpcResponse,
    summary="Google Maps Grounding Lite MCP endpoint (mock)",
    description=(
        "Mock implementation of the Google Maps Grounding Lite MCP server. "
        "Accepts JSON-RPC 2.0 requests for `tools/list` and `tools/call`."
    ),
)
async def mcp_endpoint(
    request: Request,
    x_goog_api_key: str | None = Header(None, alias="X-Goog-Api-Key"),
) -> JsonRpcResponse:
    """
    Handle MCP JSON-RPC 2.0 requests.

    Requires a non-empty X-Goog-Api-Key header (any value is accepted by this mock).
    """
    # 1. Validate authentication
    if not x_goog_api_key:
        # Return a JSON-RPC level error rather than an HTTP 401
        return _err(None, _UNAUTHENTICATED, "Missing X-Goog-Api-Key header")

    # 2. Parse JSON body
    try:
        body = await request.json()
    except Exception:
        return _err(None, _PARSE_ERROR, "Could not parse JSON body")

    # 3. Validate JSON-RPC envelope
    try:
        rpc_req = JsonRpcRequest(**body)
    except (ValidationError, TypeError) as exc:
        return _err(None, _INVALID_REQUEST, f"Invalid JSON-RPC request: {exc}")

    # 4. Dispatch
    try:
        if rpc_req.method == "tools/list":
            result = _handle_tools_list()
        elif rpc_req.method == "tools/call":
            if not rpc_req.params:
                return _err(
                    rpc_req.id, _INVALID_PARAMS, "Missing params for tools/call"
                )
            result = _handle_tools_call(rpc_req.params)
        else:
            return _err(
                rpc_req.id, _METHOD_NOT_FOUND, f"Method not found: {rpc_req.method}"
            )
    except (ValidationError, TypeError) as exc:
        return _err(rpc_req.id, _INVALID_PARAMS, f"Invalid parameters: {exc}")
    except ValueError as exc:
        return _err(rpc_req.id, _INVALID_PARAMS, str(exc))
    except Exception as exc:  # noqa: BLE001
        return _err(rpc_req.id, _INTERNAL_ERROR, f"Internal error: {exc}")

    return _ok(rpc_req.id, result)
