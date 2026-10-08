import json
import os
import unittest
from unittest.mock import AsyncMock, Mock, patch

import httpx

from runcoach_ai.ai_service import (
    AIServiceUnavailable,
    DEFAULT_MODEL,
    OPENROUTER_URL,
    PLAN_REQUEST_TIMEOUT_SECONDS,
    SYSTEM_PROMPT,
    _parse_training_plan_json,
    generate_coach_feedback,
    generate_training_plan,
)


class GenerateCoachFeedbackTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.run_data = {
            "distance_km": 5.0,
            "time_seconds": 1800,
            "avg_hr": 140,
            "rpe": 5,
        }
        self.engine_result = {
            "pace_formatted": "6:00",
            "training_load": 150.0,
            "intensity_zone": "Easy/Aerobic",
            "base_recommendation": "Base Aerobic Run",
        }

    async def test_sends_metrics_to_openrouter_and_returns_feedback(self) -> None:
        response = Mock()
        response.json.return_value = {
            "choices": [{"message": {"content": "Nice work today. Keep your next run easy."}}]
        }
        client = AsyncMock()
        client.__aenter__.return_value = client
        client.__aexit__.return_value = False
        client.post.return_value = response

        with (
            patch.dict(os.environ, {"OPENROUTER_API_KEY": "test-key"}, clear=True),
            patch("runcoach_ai.ai_service.httpx.AsyncClient", return_value=client) as client_class,
        ):
            feedback = await generate_coach_feedback(self.run_data, self.engine_result)

        self.assertEqual(feedback, "Nice work today. Keep your next run easy.")
        client_class.assert_called_once_with(timeout=20.0)
        client.post.assert_awaited_once()
        args, kwargs = client.post.call_args
        self.assertEqual(args[0], OPENROUTER_URL)
        self.assertEqual(kwargs["headers"]["Authorization"], "Bearer test-key")
        self.assertEqual(kwargs["json"]["model"], DEFAULT_MODEL)
        self.assertIn("exactly 2-3 short sentences", kwargs["json"]["messages"][0]["content"])
        self.assertIn("Never hallucinate", kwargs["json"]["messages"][0]["content"])
        self.assertIn("base_recommendation", kwargs["json"]["messages"][0]["content"])
        self.assertIn("Base Aerobic Run", kwargs["json"]["messages"][1]["content"])
        response.raise_for_status.assert_called_once_with()

    async def test_uses_configured_model(self) -> None:
        response = Mock()
        response.json.return_value = {"choices": [{"message": {"content": "Well done. Rest easy."}}]}
        client = AsyncMock()
        client.__aenter__.return_value = client
        client.__aexit__.return_value = False
        client.post.return_value = response

        with (
            patch.dict(
                os.environ,
                {"OPENROUTER_API_KEY": "test-key", "LLM_MODEL": "qwen/qwen-2.5-coder-32b-instruct"},
                clear=True,
            ),
            patch("runcoach_ai.ai_service.httpx.AsyncClient", return_value=client),
        ):
            await generate_coach_feedback(self.run_data, self.engine_result)

        self.assertEqual(
            client.post.call_args.kwargs["json"]["model"],
            "qwen/qwen-2.5-coder-32b-instruct",
        )

    async def test_includes_requested_language_in_feedback_prompt(self) -> None:
        response = Mock()
        response.json.return_value = {
            "choices": [{"message": {"content": "Хорошая работа. Отдохните."}}]
        }
        client = AsyncMock()
        client.__aenter__.return_value = client
        client.__aexit__.return_value = False
        client.post.return_value = response

        with (
            patch.dict(os.environ, {"OPENROUTER_API_KEY": "test-key"}, clear=True),
            patch("runcoach_ai.ai_service.httpx.AsyncClient", return_value=client),
        ):
            feedback = await generate_coach_feedback(
                self.run_data,
                self.engine_result,
                "ru",
            )

        self.assertEqual(feedback, "Хорошая работа. Отдохните.")
        request_content = client.post.call_args.kwargs["json"]["messages"][1]["content"]
        self.assertIn('"language": "ru"', request_content)
        self.assertIn("Лёгкая / аэробная", request_content)
        self.assertIn("Базовая аэробная пробежка", request_content)
        self.assertIn('exact language requested', SYSTEM_PROMPT)

    async def test_training_plan_generation_validates_weekly_json(self) -> None:
        response = Mock()
        response.json.return_value = {
            "choices": [
                {
                    "message": {
                        "content": json.dumps(
                            {
                                "title": "План",
                                "overview": "Постепенная подготовка.",
                                "weeks": [
                                    {
                                        "week": 1,
                                        "focus": "Базовая выносливость",
                                        "workouts": [
                                            {
                                                "day": "Понедельник",
                                                "title": "Лёгкий бег",
                                                "description": "Бегите спокойно.",
                                                "duration_minutes": 30,
                                            },
                                            {
                                                "day": "Среда",
                                                "title": "Темп",
                                                "description": "Умеренная нагрузка.",
                                                "duration_minutes": 35,
                                            },
                                            {
                                                "day": "Суббота",
                                                "title": "Длительный бег",
                                                "description": "Сохраняйте лёгкий темп.",
                                                "duration_minutes": 45,
                                            },
                                        ],
                                    }
                                ],
                            },
                            ensure_ascii=False,
                        )
                    }
                }
            ]
        }
        plan_content = response.json.return_value["choices"][0]["message"]["content"]
        response.json.return_value["choices"][0]["message"]["content"] = (
            f"Here is your plan:\n```json\n{plan_content}\n```\n"
        )
        client = AsyncMock()
        client.__aenter__.return_value = client
        client.__aexit__.return_value = False
        client.post.return_value = response

        with (
            patch.dict(os.environ, {"OPENROUTER_API_KEY": "test-key"}, clear=True),
            patch(
                "runcoach_ai.ai_service.httpx.AsyncClient",
                return_value=client,
            ) as client_class,
        ):
            plan = await generate_training_plan(
                "Алматинский полумарафон",
                "beginner",
                1,
                "ru",
            )

        self.assertEqual(plan.weeks[0].week, 1)
        self.assertEqual(plan.weeks[0].workouts[0].duration_minutes, 30)
        self.assertEqual(
            _parse_training_plan_json(
                f'Provider note {{"status":"ok"}}\n{plan_content}'
            ).title,
            "План",
        )
        client_class.assert_called_once_with(
            timeout=PLAN_REQUEST_TIMEOUT_SECONDS,
        )
        content = client.post.call_args.kwargs["json"]["messages"][1]["content"]
        self.assertIn('"language": "ru"', content)

    async def test_training_plan_rejects_missing_weeks_or_invalid_shape(self) -> None:
        response = Mock()
        response.json.return_value = {
            "choices": [{"message": {"content": '{"title":"Plan","overview":"x","weeks":[]}'}}]
        }
        client = AsyncMock()
        client.__aenter__.return_value = client
        client.__aexit__.return_value = False
        client.post.return_value = response

        with (
            patch.dict(os.environ, {"OPENROUTER_API_KEY": "test-key"}, clear=True),
            patch("runcoach_ai.ai_service.httpx.AsyncClient", return_value=client),
        ):
            with self.assertRaises(AIServiceUnavailable):
                await generate_training_plan("5k", "beginner", 1, "en")

    async def test_training_plan_reports_missing_provider_configuration(self) -> None:
        with (
            patch.dict(os.environ, {}, clear=True),
            patch("runcoach_ai.ai_service.httpx.AsyncClient") as client_class,
        ):
            with self.assertRaises(AIServiceUnavailable) as raised:
                await generate_training_plan("5k", "beginner", 1, "en")

        self.assertEqual(raised.exception.code, "plan_ai_not_configured")
        client_class.assert_not_called()

    async def test_training_plan_maps_provider_timeout_to_specific_error(self) -> None:
        client = AsyncMock()
        client.__aenter__.return_value = client
        client.__aexit__.return_value = False
        client.post.side_effect = httpx.TimeoutException("timed out")

        with (
            patch.dict(os.environ, {"OPENROUTER_API_KEY": "test-key"}, clear=True),
            patch("runcoach_ai.ai_service.httpx.AsyncClient", return_value=client),
        ):
            with self.assertRaises(AIServiceUnavailable) as raised:
                await generate_training_plan("5k", "beginner", 1, "en")

        self.assertEqual(raised.exception.code, "plan_ai_timeout")

    async def test_missing_api_key_returns_fallback_without_request(self) -> None:
        with (
            patch.dict(os.environ, {}, clear=True),
            patch("runcoach_ai.ai_service.httpx.AsyncClient") as client_class,
        ):
            feedback = await generate_coach_feedback(self.run_data, self.engine_result)

        self.assertEqual(
            feedback,
            "Great effort on your run! Based on your metrics, your next session should be: "
            "Base Aerobic Run.",
        )
        client_class.assert_not_called()

    async def test_http_error_returns_fallback(self) -> None:
        client = AsyncMock()
        client.__aenter__.return_value = client
        client.__aexit__.return_value = False
        client.post.side_effect = httpx.TimeoutException("request timed out")

        with (
            patch.dict(os.environ, {"OPENROUTER_API_KEY": "test-key"}, clear=True),
            patch("runcoach_ai.ai_service.httpx.AsyncClient", return_value=client),
        ):
            feedback = await generate_coach_feedback(self.run_data, self.engine_result)

        self.assertTrue(feedback.endswith("Base Aerobic Run."))

    async def test_api_error_response_returns_fallback(self) -> None:
        response = Mock()
        response.raise_for_status.side_effect = httpx.HTTPStatusError(
            "server error",
            request=Mock(),
            response=Mock(),
        )
        client = AsyncMock()
        client.__aenter__.return_value = client
        client.__aexit__.return_value = False
        client.post.return_value = response

        with (
            patch.dict(os.environ, {"OPENROUTER_API_KEY": "test-key"}, clear=True),
            patch("runcoach_ai.ai_service.httpx.AsyncClient", return_value=client),
        ):
            feedback = await generate_coach_feedback(self.run_data, self.engine_result)

        self.assertTrue(feedback.endswith("Base Aerobic Run."))

    async def test_malformed_response_returns_fallback(self) -> None:
        response = Mock()
        response.json.return_value = {"choices": []}
        client = AsyncMock()
        client.__aenter__.return_value = client
        client.__aexit__.return_value = False
        client.post.return_value = response

        with (
            patch.dict(os.environ, {"OPENROUTER_API_KEY": "test-key"}, clear=True),
            patch("runcoach_ai.ai_service.httpx.AsyncClient", return_value=client),
        ):
            feedback = await generate_coach_feedback(self.run_data, self.engine_result)

        self.assertTrue(feedback.endswith("Base Aerobic Run."))

    async def test_missing_recommendation_returns_safe_fallback(self) -> None:
        feedback = await generate_coach_feedback(self.run_data, {})

        self.assertEqual(
            feedback,
            "Great effort on your run! Based on your metrics, your next session should be: "
            "a suitable next session.",
        )


class TrainingPlanParserTests(unittest.TestCase):
    def setUp(self) -> None:
        self.plan = {
            "title": "Foundation plan",
            "overview": "Build consistency with gradual workouts.",
            "weeks": [
                {
                    "week": 1,
                    "focus": "Easy foundation",
                    "workouts": [
                        {
                            "day": day,
                            "title": "Easy run",
                            "description": "Keep the effort comfortable.",
                            "duration_minutes": 30,
                        }
                        for day in ("Monday", "Wednesday", "Saturday")
                    ],
                }
            ],
        }

    def test_parses_whitespace_and_markdown_json_fence(self) -> None:
        content = " \n```json\n" + json.dumps(self.plan) + "\n```\n "

        parsed = _parse_training_plan_json(content)

        self.assertEqual(parsed.title, "Foundation plan")
        self.assertEqual(parsed.weeks[0].workouts[0].duration_minutes, 30)

    def test_parses_plan_nested_in_json_wrapper_and_surrounding_prose(self) -> None:
        content = (
            "Generated plan:\n"
            + json.dumps({"response": {"result": {"training_plan": self.plan}}})
            + "\nEnjoy!"
        )

        parsed = _parse_training_plan_json(content)

        self.assertEqual(parsed.model_dump(), self.plan)


if __name__ == "__main__":
    unittest.main()
