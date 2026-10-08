import unittest
from unittest.mock import AsyncMock, Mock, patch

from runcoach_ai.weather_service import (
    OPEN_METEO_URL,
    fallback_clothing_recommendation,
    fetch_weather,
)


class WeatherServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_fetches_open_meteo_current_weather_and_daily_forecast(self) -> None:
        response = Mock()
        response.json.return_value = {
            "timezone": "Asia/Almaty",
            "current": {
                "temperature_2m": 12.4,
                "apparent_temperature": 11.0,
                "relative_humidity_2m": 60,
                "precipitation": 0.0,
                "weather_code": 1,
                "wind_speed_10m": 8.0,
            },
            "daily": {
                "time": ["2026-10-03"],
                "weather_code": [61],
                "temperature_2m_min": [8.0],
                "temperature_2m_max": [16.0],
                "precipitation_probability_max": [40],
            },
        }
        client = AsyncMock()
        client.__aenter__.return_value = client
        client.__aexit__.return_value = False
        client.get.return_value = response

        with patch(
            "runcoach_ai.weather_service.httpx.AsyncClient",
            return_value=client,
        ) as client_factory:
            result = await fetch_weather(43.2, 76.9, "ru")

        client_factory.assert_called_once_with(timeout=10)
        client.get.assert_awaited_once()
        self.assertEqual(client.get.call_args.args[0], OPEN_METEO_URL)
        response.raise_for_status.assert_called_once_with()
        self.assertEqual(result["current"]["description"], "Преимущественно ясно")
        self.assertEqual(result["forecast"]["description"], "Небольшой дождь")
        self.assertEqual(result["forecast"]["precipitation_probability"], 40)

    def test_weather_fallback_advice_handles_heat_rain_and_thunderstorms(self) -> None:
        self.assertIn(
            "indoors",
            fallback_clothing_recommendation(20, 95, "en"),
        )
        self.assertIn(
            "waterproof",
            fallback_clothing_recommendation(10, 63, "en"),
        )
        self.assertIn(
            "кепку",
            fallback_clothing_recommendation(29, 0, "ru"),
        )


if __name__ == "__main__":
    unittest.main()
