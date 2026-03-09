"""
Pydantic models for the Google Maps Grounding Lite MCP server protocol.

Reference: https://developers.google.com/maps/ai/grounding-lite/reference/mcp
"""

from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# JSON-RPC 2.0 envelope
# ---------------------------------------------------------------------------


class JsonRpcRequest(BaseModel):
    jsonrpc: Literal["2.0"] = "2.0"
    id: int | str | None = None
    method: str
    params: dict[str, Any] | None = None


class JsonRpcError(BaseModel):
    code: int
    message: str
    data: Any | None = None


class JsonRpcResponse(BaseModel):
    jsonrpc: Literal["2.0"] = "2.0"
    id: int | str | None = None
    result: Any | None = None
    error: JsonRpcError | None = None


# ---------------------------------------------------------------------------
# Shared geo types
# ---------------------------------------------------------------------------


class LatLng(BaseModel):
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)


# ---------------------------------------------------------------------------
# Tool: search_places — input
# ---------------------------------------------------------------------------


class Circle(BaseModel):
    center: LatLng
    radiusMeters: float | None = None


class LocationBias(BaseModel):
    circle: Circle | None = None


class SearchPlacesRequest(BaseModel):
    textQuery: str
    languageCode: str | None = None
    regionCode: str | None = None
    pageSize: int | None = None
    pageToken: str | None = None
    locationBias: LocationBias | None = None


# ---------------------------------------------------------------------------
# Tool: search_places — output
# ---------------------------------------------------------------------------


class GoogleMapsLinks(BaseModel):
    directionsUrl: str
    placeUrl: str
    writeAReviewUrl: str
    reviewsUrl: str
    photosUrl: str


class PlaceView(BaseModel):
    place: str  # "places/{id}"
    id: str
    location: LatLng | None = None
    googleMapsLinks: GoogleMapsLinks | None = None


class SearchPlacesResponse(BaseModel):
    places: list[PlaceView]
    summary: str
    nextPageToken: str | None = None


# ---------------------------------------------------------------------------
# Tool: lookup_weather — input
# ---------------------------------------------------------------------------


class Date(BaseModel):
    year: int
    month: int
    day: int


class WeatherLocation(BaseModel):
    latLng: LatLng | None = None
    placeId: str | None = None
    address: str | None = None


class LookupWeatherRequest(BaseModel):
    location: WeatherLocation
    unitsSystem: Literal["METRIC", "IMPERIAL"] = "METRIC"
    date: Date | None = None
    hour: int | None = Field(None, ge=0, le=23)


# ---------------------------------------------------------------------------
# Tool: lookup_weather — output
# ---------------------------------------------------------------------------


class Temperature(BaseModel):
    degrees: float
    unit: str  # "CELSIUS" or "FAHRENHEIT"


class WindSpeed(BaseModel):
    value: float
    unit: str  # "KILOMETERS_PER_HOUR" or "MILES_PER_HOUR"


class WindDirection(BaseModel):
    degrees: float


class Wind(BaseModel):
    speed: WindSpeed
    gust: WindSpeed | None = None
    direction: WindDirection | None = None


class Precipitation(BaseModel):
    probability: float | None = None  # 0-100
    qpf: float | None = None  # quantity mm or inches


class Celestial(BaseModel):
    sunriseTime: str | None = None  # ISO 8601
    sunsetTime: str | None = None
    moonPhase: str | None = None


class CurrentConditions(BaseModel):
    temperature: Temperature
    feelsLike: Temperature | None = None
    humidity: float | None = None  # percentage
    uvIndex: float | None = None
    cloudCover: float | None = None  # percentage
    wind: Wind | None = None
    precipitation: Precipitation | None = None
    condition: str | None = None  # e.g. "Partly Cloudy"
    celestial: Celestial | None = None


class HourlyForecast(BaseModel):
    hour: int
    temperature: Temperature
    condition: str
    wind: Wind | None = None
    precipitation: Precipitation | None = None


class DailyForecast(BaseModel):
    date: Date
    temperatureHigh: Temperature
    temperatureLow: Temperature
    condition: str
    wind: Wind | None = None
    precipitation: Precipitation | None = None
    celestial: Celestial | None = None


class LookupWeatherResponse(BaseModel):
    geocodedAddress: str | None = None
    currentConditions: CurrentConditions | None = None
    hourlyForecast: list[HourlyForecast] | None = None
    dailyForecast: list[DailyForecast] | None = None


# ---------------------------------------------------------------------------
# Tool: compute_routes — input
# ---------------------------------------------------------------------------


class Waypoint(BaseModel):
    latLng: LatLng | None = None
    placeId: str | None = None
    address: str | None = None


class ComputeRoutesRequest(BaseModel):
    origin: Waypoint
    destination: Waypoint
    travelMode: Literal["DRIVE", "WALK"] = "DRIVE"


# ---------------------------------------------------------------------------
# Tool: compute_routes — output
# ---------------------------------------------------------------------------


class Duration(BaseModel):
    seconds: str
    nanos: int = 0


class Route(BaseModel):
    distanceMeters: int
    duration: Duration


class ComputeRoutesResponse(BaseModel):
    routes: list[Route]


# ---------------------------------------------------------------------------
# MCP tools/list response shapes
# ---------------------------------------------------------------------------


class ToolDefinition(BaseModel):
    name: str
    description: str
    inputSchema: dict[str, Any]


class ToolsListResult(BaseModel):
    tools: list[ToolDefinition]
