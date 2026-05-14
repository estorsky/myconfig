#!/usr/bin/env python3

from datetime import datetime
import html
import json
import os
import sys
import time
import urllib.parse
import urllib.request


DEFAULT_CITY = "Novosibirsk"
REQUEST_TIMEOUT_SEC = 5
HOURLY_ENTRIES = 8
CACHE_TTL_SEC = 900
CACHE_FILENAME = "waybar-weather.json"


def fetch_json(url):
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "waybar-weather/1.0",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SEC) as response:
        return json.load(response)


def weather_appearance(code):
    if code == 0:
        return "", "clear", "Clear sky"
    if code in (1, 2):
        return "", "partly-cloudy", "Partly cloudy"
    if code == 3:
        return "", "cloudy", "Overcast"
    if code in (45, 48):
        return "", "fog", "Fog"
    if code in (51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82):
        return "", "rain", "Rain"
    if code in (71, 73, 75, 77, 85, 86):
        return "", "snow", "Snow"
    if code in (95, 96, 99):
        return "", "storm", "Thunderstorm"
    return "", "default", "Weather"


def weather_color(css_class):
    return {
        "clear": "#d5aa73",
        "partly-cloudy": "#d5aa73",
        "cloudy": "#a6b2d2",
        "fog": "#a6b2d2",
        "rain": "#91c4f0",
        "snow": "#c1cae9",
        "storm": "#d07d8e",
        "default": "#c1cae9",
        "error": "#d07d8e",
    }.get(css_class, "#c1cae9")


def span(text, *, foreground=None, font_family=None, weight=None):
    attrs = []
    if foreground:
        attrs.append(f'foreground="{foreground}"')
    if font_family:
        attrs.append(f'font_family="{font_family}"')
    if weight:
        attrs.append(f'weight="{weight}"')
    attr_text = ""
    if attrs:
        attr_text = " " + " ".join(attrs)
    return f"<span{attr_text}>{html.escape(text)}</span>"


def format_daily_forecast(daily):
    days = []
    for day, code, temp_min, temp_max, precip in zip(
        daily["time"],
        daily["weather_code"],
        daily["temperature_2m_min"],
        daily["temperature_2m_max"],
        daily["precipitation_probability_max"],
    ):
        icon, _, _ = weather_appearance(int(code))
        weekday = datetime.fromisoformat(day).strftime("%a")
        precip_value = "--" if precip is None else f"{round(precip):>2}%"
        days.append(f"{weekday:<4} {round(temp_min):>3}° {round(temp_max):>3}° {precip_value:>3} {icon}")
    return days


def find_hourly_start_index(current_time, hourly_times):
    current_dt = datetime.fromisoformat(current_time)

    for idx, hourly_time in enumerate(hourly_times):
        hourly_dt = datetime.fromisoformat(hourly_time)
        if hourly_dt >= current_dt:
            return idx

    return max(0, len(hourly_times) - HOURLY_ENTRIES)


def format_hourly_forecast(current_time, hourly):
    start_idx = find_hourly_start_index(current_time, hourly["time"])

    lines = []
    end_idx = min(start_idx + HOURLY_ENTRIES, len(hourly["time"]))
    for idx in range(start_idx, end_idx):
        icon, _, _ = weather_appearance(int(hourly["weather_code"][idx]))
        hour = datetime.fromisoformat(hourly["time"][idx]).strftime("%H:%M")
        precip = hourly["precipitation_probability"][idx]
        precip_value = "--" if precip is None else f"{round(precip):>2}%"
        temp = round(hourly["temperature_2m"][idx])
        lines.append(f"{hour:<5} {temp:>3}° {precip_value:>3} {icon}")
    return lines


def build_tooltip(
    location,
    description,
    temperature,
    feels_like,
    humidity,
    wind_speed,
    temp_min,
    temp_max,
    hourly_lines,
    weekly_lines,
    css_class,
):
    accent = weather_color(css_class)
    muted = "#8f9ac6"
    mono = "Noto Sans Mono"

    lines = [
        span(location, foreground="#c1cae9", weight="600"),
        "",
        span(f"Now   {temperature:>3} °C   {description}", foreground=accent),
        span(f"Feel  {feels_like:>3} °C", foreground="#c1cae9"),
        span(f"Hum   {humidity:>3} %", foreground="#c1cae9"),
        span(f"Wind  {wind_speed:>3} km/h", foreground="#c1cae9"),
        span(f"Day   {temp_min:>3} °C / {temp_max:>3} °C", foreground="#c1cae9"),
        "",
        span("Hour  Temp Pop W", foreground=muted, font_family=mono, weight="600"),
        *[span(line, foreground="#c1cae9", font_family=mono) for line in hourly_lines],
        "",
        span("Day   Min  Max Pop W", foreground=muted, font_family=mono, weight="600"),
        *[span(line, foreground="#c1cae9", font_family=mono) for line in weekly_lines],
    ]
    return "\n".join(lines)


def output(payload):
    print(json.dumps(payload, ensure_ascii=False))


def get_cache_path():
    cache_home = os.environ.get("XDG_CACHE_HOME")
    if not cache_home:
        cache_home = os.path.join(os.path.expanduser("~"), ".cache")
    return os.path.join(cache_home, CACHE_FILENAME)


def load_cached_payload():
    try:
        with open(get_cache_path(), encoding="utf-8") as cache_file:
            cached = json.load(cache_file)
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        return None

    payload = cached.get("payload")
    fetched_at = cached.get("fetched_at")
    if not isinstance(payload, dict) or not isinstance(fetched_at, (int, float)):
        return None

    return {"payload": payload, "fetched_at": fetched_at}


def save_cached_payload(payload):
    cache_path = get_cache_path()
    os.makedirs(os.path.dirname(cache_path), exist_ok=True)
    temp_path = cache_path + ".tmp"
    cached = {"fetched_at": time.time(), "payload": payload}
    with open(temp_path, "w", encoding="utf-8") as cache_file:
        json.dump(cached, cache_file, ensure_ascii=False)
    os.replace(temp_path, cache_path)


def cached_payload_is_fresh(cached_payload):
    return time.time() - cached_payload["fetched_at"] < CACHE_TTL_SEC


def with_cached_notice(payload):
    cached_payload = dict(payload)
    cached_payload["tooltip"] = (
        payload.get("tooltip", "")
        + "\n\n"
        + span("Offline, showing cached weather", foreground="#8f9ac6")
    )
    return cached_payload


def main():
    city = os.environ.get("WAYBAR_WEATHER_CITY", DEFAULT_CITY)
    cached_payload = load_cached_payload()

    if cached_payload and cached_payload_is_fresh(cached_payload):
        output(cached_payload["payload"])
        return 0

    geocode_url = (
        "https://geocoding-api.open-meteo.com/v1/search?"
        + urllib.parse.urlencode(
            {
                "name": city,
                "count": 1,
                "language": "en",
                "format": "json",
            }
        )
    )

    try:
        geocode = fetch_json(geocode_url)
        results = geocode.get("results") or []
        if not results:
            raise RuntimeError(f"location not found: {city}")

        place = results[0]
        latitude = place["latitude"]
        longitude = place["longitude"]
        resolved_name = place["name"]

        weather_url = (
            "https://api.open-meteo.com/v1/forecast?"
            + urllib.parse.urlencode(
                {
                    "latitude": latitude,
                    "longitude": longitude,
                    "timezone": "auto",
                    "forecast_days": 7,
                    "current": ",".join(
                        [
                            "temperature_2m",
                            "apparent_temperature",
                            "relative_humidity_2m",
                            "weather_code",
                            "wind_speed_10m",
                        ]
                    ),
                    "hourly": ",".join(
                        [
                            "temperature_2m",
                            "precipitation_probability",
                            "weather_code",
                        ]
                    ),
                    "daily": ",".join(
                        [
                            "weather_code",
                            "temperature_2m_min",
                            "temperature_2m_max",
                            "precipitation_probability_max",
                        ]
                    ),
                }
            )
        )
        weather = fetch_json(weather_url)

        current = weather["current"]
        hourly = weather["hourly"]
        daily = weather["daily"]
        current_time = current["time"]
        temperature = round(current["temperature_2m"])
        feels_like = round(current["apparent_temperature"])
        humidity = round(current["relative_humidity_2m"])
        wind_speed = round(current["wind_speed_10m"])
        weather_code = int(current["weather_code"])
        temp_min = round(daily["temperature_2m_min"][0])
        temp_max = round(daily["temperature_2m_max"][0])

        icon, css_class, description = weather_appearance(weather_code)
        location = resolved_name
        hourly_lines = format_hourly_forecast(current_time, hourly)
        weekly_lines = format_daily_forecast(daily)

        payload = {
            "text": f"{temperature}° {icon}",
            "tooltip": build_tooltip(
                location,
                description,
                temperature,
                feels_like,
                humidity,
                wind_speed,
                temp_min,
                temp_max,
                hourly_lines,
                weekly_lines,
                css_class,
            ),
            "class": css_class,
        }
        save_cached_payload(payload)
        output(payload)
    except Exception as exc:
        if cached_payload:
            output(with_cached_notice(cached_payload["payload"]))
            return 0

        output(
            {
                "text": "--°",
                "tooltip": f"Weather unavailable for {city}\n{exc}",
                "class": "error",
            }
        )
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
