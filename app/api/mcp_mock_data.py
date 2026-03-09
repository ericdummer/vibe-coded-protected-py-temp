"""
Mock response builders for the Google Maps Grounding Lite MCP tools.

Returns realistic but fully synthetic data — no real API calls are made.
"""

from __future__ import annotations

import math
from typing import Any

from app.models.mcp_models import (
    Celestial,
    ComputeRoutesRequest,
    ComputeRoutesResponse,
    CurrentConditions,
    DailyForecast,
    Date,
    Duration,
    GoogleMapsLinks,
    HourlyForecast,
    LatLng,
    LookupWeatherRequest,
    LookupWeatherResponse,
    PlaceView,
    Precipitation,
    Route,
    SearchPlacesRequest,
    SearchPlacesResponse,
    Temperature,
    Wind,
    WindDirection,
    WindSpeed,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_PLACE_ID_SEED = "ChIJmock"


def _place_id(index: int) -> str:
    return f"{_PLACE_ID_SEED}{index:04d}AAAA"


def _maps_links(place_id: str, lat: float, lng: float) -> GoogleMapsLinks:
    base = "https://maps.google.com"
    return GoogleMapsLinks(
        directionsUrl=f"{base}/maps/dir/?api=1&destination={lat},{lng}",
        placeUrl=f"{base}/maps/place/?q=place_id:{place_id}",
        writeAReviewUrl=f"{base}/maps/place/?q=place_id:{place_id}&action=write-review",
        reviewsUrl=f"{base}/maps/place/?q=place_id:{place_id}&action=reviews",
        photosUrl=f"{base}/maps/place/?q=place_id:{place_id}&action=photos",
    )


# Default centre for mocked coordinates when none is provided
_DEFAULT_LAT = 37.7749
_DEFAULT_LNG = -122.4194  # San Francisco

# Spread mock results around the query centre
_OFFSET_STEP = 0.005


def _offset_lat_lng(
    base_lat: float,
    base_lng: float,
    index: int,
) -> tuple[float, float]:
    angle = (index * 60) % 360
    rad = math.radians(angle)
    spread = _OFFSET_STEP * (1 + index * 0.3)
    return (
        round(base_lat + spread * math.cos(rad), 6),
        round(base_lng + spread * math.sin(rad), 6),
    )


def _mock_place_name(query: str, index: int) -> str:
    suffixes = ["Place", "Spot", "Hub", "Corner", "Point"]
    suffix = suffixes[index % len(suffixes)]
    short = query.split()[0].title() if query else "Mock"
    return f"{short} {suffix} #{index + 1}"


# ---------------------------------------------------------------------------
# search_places
# ---------------------------------------------------------------------------


def build_search_places_response(req: SearchPlacesRequest) -> dict[str, Any]:
    """Return a mock SearchTextResponse JSON dict."""
    query = req.textQuery
    count = min(req.pageSize or 5, 5)

    # Determine centre coordinates
    if req.locationBias and req.locationBias.circle:
        centre = req.locationBias.circle.center
        base_lat, base_lng = centre.latitude, centre.longitude
    else:
        base_lat, base_lng = _DEFAULT_LAT, _DEFAULT_LNG

    places: list[PlaceView] = []
    for i in range(count):
        lat, lng = _offset_lat_lng(base_lat, base_lng, i)
        pid = _place_id(i)
        places.append(
            PlaceView(
                place=f"places/{pid}",
                id=pid,
                location=LatLng(latitude=lat, longitude=lng),
                googleMapsLinks=_maps_links(pid, lat, lng),
            )
        )

    place_names = [_mock_place_name(query, i) for i in range(count)]
    citations = " ".join(f"[{i}]" for i in range(count))
    summary = (
        f"Here are the top results for '{query}': "
        + ", ".join(place_names)
        + f". {citations}"
    )

    resp = SearchPlacesResponse(places=places, summary=summary)
    return resp.model_dump(exclude_none=True)


# ---------------------------------------------------------------------------
# lookup_weather
# ---------------------------------------------------------------------------

_CONDITIONS = [
    "Partly Cloudy",
    "Mostly Sunny",
    "Overcast",
    "Light Rain",
    "Clear",
]


def _temp(degrees: float, units: str) -> Temperature:
    return Temperature(
        degrees=degrees, unit="FAHRENHEIT" if units == "IMPERIAL" else "CELSIUS"
    )


def _wind(speed_val: float, units: str) -> Wind:
    unit = "MILES_PER_HOUR" if units == "IMPERIAL" else "KILOMETERS_PER_HOUR"
    return Wind(
        speed=WindSpeed(value=speed_val, unit=unit),
        gust=WindSpeed(value=speed_val + 5, unit=unit),
        direction=WindDirection(degrees=180.0),
    )


def build_lookup_weather_response(req: LookupWeatherRequest) -> dict[str, Any]:
    """Return a mock LookupWeatherResponse JSON dict."""
    units = req.unitsSystem

    # Determine a display address from whatever location was provided
    if req.location.address:
        address = req.location.address
    elif (
        req.location.place_id
        if hasattr(req.location, "place_id")
        else req.location.placeId
    ):
        pid = req.location.placeId or ""
        address = f"Place ID: {pid}"
    elif req.location.latLng:
        ll = req.location.latLng
        address = f"{ll.latitude:.4f}, {ll.longitude:.4f}"
    else:
        address = "Unknown Location"

    base_temp = 22.0 if units == "METRIC" else 72.0

    result = LookupWeatherResponse(geocodedAddress=address)

    if req.date and req.hour is not None:
        # Hourly forecast — return a single hourly entry
        result.hourlyForecast = [
            HourlyForecast(
                hour=req.hour,
                temperature=_temp(base_temp + req.hour * 0.3, units),
                condition=_CONDITIONS[req.hour % len(_CONDITIONS)],
                wind=_wind(12.0, units),
                precipitation=Precipitation(probability=20.0, qpf=0.0),
            )
        ]
    elif req.date:
        # Daily forecast — 7 days starting from the requested date
        daily: list[DailyForecast] = []
        for offset in range(7):
            day_num = req.date.day + offset
            daily.append(
                DailyForecast(
                    date=Date(year=req.date.year, month=req.date.month, day=day_num),
                    temperatureHigh=_temp(base_temp + 4 + offset * 0.5, units),
                    temperatureLow=_temp(base_temp - 6 - offset * 0.5, units),
                    condition=_CONDITIONS[offset % len(_CONDITIONS)],
                    wind=_wind(10.0 + offset, units),
                    precipitation=Precipitation(
                        probability=float(10 * (offset % 4)), qpf=0.0
                    ),
                    celestial=Celestial(
                        sunriseTime="06:30:00",
                        sunsetTime="19:45:00",
                        moonPhase="WAXING_CRESCENT",
                    ),
                )
            )
        result.dailyForecast = daily
    else:
        # Current conditions
        result.currentConditions = CurrentConditions(
            temperature=_temp(base_temp, units),
            feelsLike=_temp(base_temp - 2, units),
            humidity=65.0,
            uvIndex=5.0,
            cloudCover=40.0,
            wind=_wind(15.0, units),
            precipitation=Precipitation(probability=10.0, qpf=0.0),
            condition="Partly Cloudy",
            celestial=Celestial(
                sunriseTime="06:32:00",
                sunsetTime="19:48:00",
                moonPhase="FULL_MOON",
            ),
        )

    return result.model_dump(exclude_none=True)


# ---------------------------------------------------------------------------
# compute_routes
# ---------------------------------------------------------------------------

_METERS_PER_KM = 1000


def _waypoint_label(wp: Any) -> str:
    if wp.address:
        return wp.address
    if wp.placeId:
        return f"place:{wp.placeId}"
    if wp.latLng:
        return f"{wp.latLng.latitude:.4f},{wp.latLng.longitude:.4f}"
    return "unknown"


def build_compute_routes_response(req: ComputeRoutesRequest) -> dict[str, Any]:
    """Return a mock ComputeRoutesResponse JSON dict."""
    # Use a rough heuristic: driving ~30 km at 50 km/h ≈ 36 min
    # Walking ~3 km at 5 km/h ≈ 36 min
    if req.travelMode == "WALK":
        distance_m = 3200
        duration_s = 2304  # ~38 min
    else:
        distance_m = 28500
        duration_s = 2160  # ~36 min

    resp = ComputeRoutesResponse(
        routes=[
            Route(
                distanceMeters=distance_m,
                duration=Duration(seconds=str(duration_s), nanos=0),
            )
        ]
    )
    return resp.model_dump(exclude_none=True)
