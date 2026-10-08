"""Open-Meteo weather lookup and localized conditions."""

from typing import Any, Literal

import httpx


OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"
WEATHER_DESCRIPTIONS: dict[int, tuple[str, str]] = {
    0: ("Clear sky", "Ясно"),
    1: ("Mainly clear", "Преимущественно ясно"),
    2: ("Partly cloudy", "Переменная облачность"),
    3: ("Overcast", "Пасмурно"),
    45: ("Foggy", "Туман"),
    48: ("Rime fog", "Изморозь и туман"),
    51: ("Light drizzle", "Лёгкая морось"),
    53: ("Drizzle", "Морось"),
    55: ("Dense drizzle", "Сильная морось"),
    61: ("Light rain", "Небольшой дождь"),
    63: ("Rain", "Дождь"),
    65: ("Heavy rain", "Сильный дождь"),
    71: ("Light snow", "Небольшой снег"),
    73: ("Snow", "Снег"),
    75: ("Heavy snow", "Сильный снег"),
    80: ("Rain showers", "Ливневый дождь"),
    81: ("Rain showers", "Ливневый дождь"),
    82: ("Heavy rain showers", "Сильные ливни"),
    95: ("Thunderstorm", "Гроза"),
    96: ("Thunderstorm with hail", "Гроза с градом"),
    99: ("Thunderstorm with hail", "Гроза с градом"),
}


async def fetch_weather(
    latitude: float,
    longitude: float,
    language: Literal["en", "ru"],
) -> dict[str, Any]:
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "current": (
            "temperature_2m,apparent_temperature,relative_humidity_2m,"
            "precipitation,weather_code,wind_speed_10m"
        ),
        "daily": "weather_code,temperature_2m_max,temperature_2m_min,"
        "precipitation_probability_max",
        "forecast_days": 1,
        "timezone": "auto",
    }
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.get(OPEN_METEO_URL, params=params)
    response.raise_for_status()
    data = response.json()
    current = data["current"]
    daily = data["daily"]
    code = int(current["weather_code"])
    daily_code = int(daily["weather_code"][0])
    current_description = WEATHER_DESCRIPTIONS.get(
        code,
        ("Variable conditions", "Переменчивая погода"),
    )
    forecast_description = WEATHER_DESCRIPTIONS.get(
        daily_code,
        ("Variable conditions", "Переменчивая погода"),
    )
    return {
        "location": {
            "latitude": latitude,
            "longitude": longitude,
            "timezone": data.get("timezone"),
        },
        "current": {
            "temperature_c": float(current["temperature_2m"]),
            "feels_like_c": float(current["apparent_temperature"]),
            "relative_humidity": int(current["relative_humidity_2m"]),
            "precipitation_mm": float(current["precipitation"]),
            "wind_speed_kmh": float(current["wind_speed_10m"]),
            "weather_code": code,
            "description": current_description[0 if language == "en" else 1],
        },
        "forecast": {
            "date": daily["time"][0],
            "temperature_min_c": float(daily["temperature_2m_min"][0]),
            "temperature_max_c": float(daily["temperature_2m_max"][0]),
            "precipitation_probability": int(
                daily["precipitation_probability_max"][0]
            ),
            "weather_code": daily_code,
            "description": forecast_description[0 if language == "en" else 1],
        },
    }


def fallback_clothing_recommendation(
    temperature_c: float,
    weather_code: int,
    language: Literal["en", "ru"],
) -> str:
    is_russian = language == "ru"
    if weather_code >= 95:
        return (
            "Лучше перенести пробежку в помещение из-за грозы."
            if is_russian
            else "Consider moving your run indoors because of thunderstorms."
        )
    if weather_code in {61, 63, 65, 80, 81, 82}:
        return (
            "Наденьте лёгкую водонепроницаемую куртку и обувь с хорошим сцеплением."
            if is_russian
            else "Wear a lightweight waterproof jacket and shoes with good grip."
        )
    if temperature_c < 5:
        return (
            "Выберите термобельё, лёгкую ветровку, перчатки и шапку."
            if is_russian
            else "Wear a thermal base layer, a light windproof jacket, gloves, and a hat."
        )
    if temperature_c < 15:
        return (
            "Наденьте дышащие слои и лёгкую ветровку."
            if is_russian
            else "Wear breathable layers and a lightweight windbreaker."
        )
    if temperature_c >= 25:
        return (
            "Выберите лёгкую дышащую одежду и кепку; в жару снизьте темп."
            if is_russian
            else "Choose lightweight breathable clothes and a cap; slow down in the heat."
        )
    return (
        "Выберите лёгкую дышащую одежду для бега."
        if is_russian
        else "Choose lightweight, breathable running clothes."
    )
