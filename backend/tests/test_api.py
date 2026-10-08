import unittest
from unittest.mock import AsyncMock, patch

import httpx
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from runcoach_ai.database import Base
from runcoach_ai.main import app
from runcoach_ai.rule_engine import RuleEngineResult
from runcoach_ai.main import get_session
from runcoach_ai.auth_service import create_access_token
from runcoach_ai.models import User


class AnalyzeRunEndpointTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        self.engine = create_async_engine("sqlite+aiosqlite:///:memory:")
        async with self.engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        self.session_factory = async_sessionmaker(self.engine, expire_on_commit=False)
        async with self.session_factory() as session:
            test_user = User(
                email="api-test-runner@example.com",
                password_hash="test-only-hash",
                first_name="API",
                last_name="Tester",
            )
            session.add(test_user)
            await session.commit()
            await session.refresh(test_user)
            access_token = create_access_token(str(test_user.id), test_user.email)

        async def override_session():
            async with self.session_factory() as session:
                yield session

        app.dependency_overrides[get_session] = override_session
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app),
            base_url="http://test",
            headers={"Authorization": f"Bearer {access_token}"},
        )

    async def asyncTearDown(self) -> None:
        await self.client.aclose()
        app.dependency_overrides.clear()
        await self.engine.dispose()

    async def test_returns_combined_deterministic_metrics_and_feedback(self) -> None:
        missing_max_hr_zones = await self.client.get("/api/v1/heart-rate-zones")
        self.assertEqual(missing_max_hr_zones.status_code, 400)

        deterministic_result = RuleEngineResult(
            pace_formatted="6:00",
            training_load=150,
            intensity_zone="Easy/Aerobic",
            base_recommendation="Base Aerobic Run",
        )
        with (
            patch("runcoach_ai.main.analyze_run_metrics", return_value=deterministic_result) as analyze,
            patch(
                "runcoach_ai.main.generate_coach_feedback",
                new_callable=AsyncMock,
                return_value="Good work. Keep your next run comfortable.",
            ) as feedback,
        ):
            response = await self.client.post(
                "/api/v1/analyze_run",
                json={
                    "distance_km": 5,
                    "time_seconds": 1800,
                    "avg_hr": 140,
                    "rpe": 5,
                },
                params={"lang": "ru"},
            )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertIn("id", body)
        self.assertIn("date", body)
        self.assertEqual(body["status"], "success")
        self.assertEqual(
            body["metrics"],
            {
                "pace": "6:00",
                "training_load": 150,
                "intensity_zone": "Лёгкая / аэробная",
            },
        )
        self.assertEqual(body["recommendation"], "Базовая аэробная пробежка")
        self.assertEqual(
            body["coach_feedback"],
            "Good work. Keep your next run comfortable.",
        )
        run_input = analyze.call_args.args[0]
        self.assertEqual(run_input.distance_km, 5)
        self.assertEqual(analyze.call_args.kwargs, {"max_hr": 195})
        feedback.assert_awaited_once_with(
            {"distance_km": 5.0, "time_seconds": 1800, "avg_hr": 140, "rpe": 5},
            deterministic_result.model_dump(),
            "ru",
        )

        history_response = await self.client.get("/api/v1/runs")
        self.assertEqual(history_response.status_code, 200)
        runs = history_response.json()["runs"]
        self.assertEqual(len(runs), 1)
        self.assertEqual(runs[0]["pace"], "6:00")
        self.assertEqual(runs[0]["training_load"], 150)
        self.assertEqual(runs[0]["recommendation"], "Base Aerobic Run")
        self.assertEqual(
            runs[0]["coach_feedback"],
            "Good work. Keep your next run comfortable.",
        )
        russian_history_response = await self.client.get(
            "/api/v1/runs",
            params={"lang": "ru"},
        )
        self.assertEqual(russian_history_response.status_code, 200)
        russian_run = russian_history_response.json()["runs"][0]
        self.assertEqual(russian_run["intensity_zone"], "Лёгкая / аэробная")
        self.assertEqual(
            russian_run["recommendation"],
            "Базовая аэробная пробежка",
        )
        deleted_response = await self.client.delete(f"/api/v1/runs/{runs[0]['id']}")
        self.assertEqual(deleted_response.status_code, 200)
        self.assertEqual(deleted_response.json(), {"status": "deleted"})
        empty_history = await self.client.get("/api/v1/runs")
        self.assertEqual(empty_history.json()["runs"], [])
        missing_delete = await self.client.delete(
            "/api/v1/runs/00000000-0000-0000-0000-000000000000"
        )
        self.assertEqual(missing_delete.status_code, 404)

    async def test_run_history_returns_recent_runs_in_descending_order(self) -> None:
        older = {
            "distance_km": 4.0,
            "time_seconds": 1500,
            "avg_hr": 135,
            "rpe": 4,
        }
        newer = {
            "distance_km": 5.0,
            "time_seconds": 1860,
            "avg_hr": 172,
            "rpe": 7,
        }

        with (
            patch(
                "runcoach_ai.main.generate_coach_feedback",
                new_callable=AsyncMock,
                side_effect=["Easy effort. Add a little distance next time.", "Strong run. Recover well."],
            ),
        ):
            await self.client.post("/api/v1/analyze_run", json=older)
            await self.client.post("/api/v1/runs", json=newer)

        response = await self.client.get("/api/v1/runs?limit=1")

        self.assertEqual(response.status_code, 200)
        runs = response.json()["runs"]
        self.assertEqual(len(runs), 1)
        self.assertEqual(runs[0]["distance_km"], 5.0)
        self.assertEqual(runs[0]["pace"], "6:12")
        self.assertEqual(runs[0]["training_load"], 217)
        self.assertEqual(runs[0]["coach_feedback"], "Strong run. Recover well.")

    async def test_rejects_invalid_run_input(self) -> None:
        response = await self.client.post(
            "/api/v1/analyze_run",
            json={
                "distance_km": 5,
                "time_seconds": 1800,
                "avg_hr": 140,
                "rpe": 11,
            },
        )

        self.assertEqual(response.status_code, 422)

    async def test_cors_preflight_allows_web_origins_methods_and_headers(self) -> None:
        response = await self.client.options(
            "/api/v1/analyze_run",
            headers={
                "Origin": "http://localhost:43127",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "authorization,content-type",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.headers["access-control-allow-origin"],
            "http://localhost:43127",
        )
        self.assertIn("POST", response.headers["access-control-allow-methods"])
        self.assertIn("content-type", response.headers["access-control-allow-headers"])
        self.assertIn(
            "authorization",
            response.headers["access-control-allow-headers"],
        )

    async def test_analysis_response_includes_cors_header(self) -> None:
        with (
            patch(
                "runcoach_ai.main.analyze_run_metrics",
                return_value=RuleEngineResult(
                    pace_formatted="6:00",
                    training_load=150,
                    intensity_zone="Easy/Aerobic",
                    base_recommendation="Base Aerobic Run",
                ),
            ),
            patch(
                "runcoach_ai.main.generate_coach_feedback",
                new_callable=AsyncMock,
                return_value="Good work. Keep your next run comfortable.",
            ),
        ):
            response = await self.client.post(
                "/api/v1/analyze_run",
                headers={"Origin": "http://localhost:5173"},
                json={
                    "distance_km": 5,
                    "time_seconds": 1800,
                    "avg_hr": 140,
                    "rpe": 5,
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.headers["access-control-allow-origin"],
            "http://localhost:5173",
        )

    async def test_analysis_returns_localized_deterministic_labels(self) -> None:
        with patch(
            "runcoach_ai.main.generate_coach_feedback",
            new_callable=AsyncMock,
            return_value="Хорошая работа. Следующая — базовая пробежка.",
        ):
            response = await self.client.post(
                "/api/v1/analyze_run?lang=ru",
                json={
                    "distance_km": 5,
                    "time_seconds": 1800,
                    "avg_hr": 140,
                    "rpe": 5,
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json()["metrics"]["intensity_zone"],
            "Лёгкая / аэробная",
        )
        self.assertEqual(
            response.json()["recommendation"],
            "Базовая аэробная пробежка",
        )

    async def test_training_plan_endpoint_returns_structured_plan(self) -> None:
        from runcoach_ai.ai_service import PlanWeek, PlanWorkout, TrainingPlan

        plan = TrainingPlan(
            title="Half Marathon Build",
            overview="Build endurance safely.",
            weeks=[
                PlanWeek(
                    week=1,
                    focus="Easy foundation",
                    workouts=[
                        PlanWorkout(
                            day="Monday",
                            title="Easy run",
                            description="Run comfortably.",
                            duration_minutes=30,
                        ),
                        PlanWorkout(
                            day="Wednesday",
                            title="Intervals",
                            description="Short controlled efforts.",
                            duration_minutes=35,
                        ),
                        PlanWorkout(
                            day="Saturday",
                            title="Long run",
                            description="Keep an easy effort.",
                            duration_minutes=45,
                        ),
                    ],
                )
            ],
        )
        with patch(
            "runcoach_ai.main.generate_training_plan",
            new_callable=AsyncMock,
            return_value=plan,
        ) as generate:
            response = await self.client.post(
                "/api/v1/generate-plan",
                params={"lang": "ru"},
                json={
                    "goal": "Almaty Half Marathon",
                    "fitness_level": "beginner",
                    "timeline_weeks": 1,
                    "language": "en",
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            set(response.json()),
            {"title", "overview", "weeks"},
        )
        self.assertEqual(response.json()["weeks"][0]["week"], 1)
        self.assertEqual(len(response.json()["weeks"][0]["workouts"]), 3)
        generate.assert_awaited_once_with(
            goal="Almaty Half Marathon",
            fitness_level="beginner",
            timeline_weeks=1,
            language="ru",
        )

    async def test_training_plan_endpoint_reports_unavailable_ai_service(self) -> None:
        from runcoach_ai.ai_service import AIServiceUnavailable

        with patch(
            "runcoach_ai.main.generate_training_plan",
            new_callable=AsyncMock,
            side_effect=AIServiceUnavailable(
                "missing provider key",
                code="plan_ai_not_configured",
            ),
        ):
            response = await self.client.post(
                "/api/v1/generate-plan",
                json={
                    "goal": "10k race",
                    "fitness_level": "beginner",
                    "timeline_weeks": 8,
                    "language": "en",
                },
            )
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json()["detail"], "plan_ai_not_configured")

    async def test_run_deletion_is_scoped_to_the_authenticated_user(self) -> None:
        with patch(
            "runcoach_ai.main.generate_coach_feedback",
            new_callable=AsyncMock,
            return_value="Good work.",
        ):
            created = await self.client.post(
                "/api/v1/analyze_run",
                json={
                    "distance_km": 5,
                    "time_seconds": 1800,
                    "avg_hr": 140,
                    "rpe": 5,
                },
            )
        self.assertEqual(created.status_code, 200)
        run_id = created.json()["id"]

        other_user = await self.client.post(
            "/api/v1/auth/register",
            json={
                "email": "other-runner@example.com",
                "password": "safe-password-123",
                "first_name": "Other",
                "last_name": "Runner",
            },
        )
        self.assertEqual(other_user.status_code, 200)
        response = await self.client.delete(
            f"/api/v1/runs/{run_id}",
            headers={
                "Authorization": f"Bearer {other_user.json()['token']}"
            },
        )

        self.assertEqual(response.status_code, 404)
        history = await self.client.get("/api/v1/runs")
        self.assertEqual([run["id"] for run in history.json()["runs"]], [run_id])

    async def test_unversioned_plan_endpoint_accepts_short_body_aliases(self) -> None:
        from runcoach_ai.ai_service import PlanWeek, PlanWorkout, TrainingPlan

        plan = TrainingPlan(
            title="Plan",
            overview="Steady progress.",
            weeks=[
                PlanWeek(
                    week=1,
                    focus="Foundation",
                    workouts=[
                        PlanWorkout(
                            day=day,
                            title="Easy run",
                            description="Keep it comfortable.",
                            duration_minutes=30,
                        )
                        for day in ("Monday", "Wednesday", "Saturday")
                    ],
                )
            ],
        )
        with patch(
            "runcoach_ai.main.generate_training_plan",
            new_callable=AsyncMock,
            return_value=plan,
        ) as generate:
            response = await self.client.post(
                "/generate-plan",
                json={
                    "goal": "10K",
                    "fitness_level": "beginner",
                    "weeks": 1,
                    "lang": "ru",
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["weeks"][0]["week"], 1)
        generate.assert_awaited_once_with(
            goal="10K",
            fitness_level="beginner",
            timeline_weeks=1,
            language="ru",
        )

    async def test_register_login_and_protect_profile(self) -> None:
        register_response = await self.client.post(
            "/api/v1/auth/register",
            json={
                "email": "Runner@Example.com",
                "password": "safe-password-123",
                "first_name": " Alex ",
                "last_name": "Runner",
            },
        )
        self.assertEqual(register_response.status_code, 200)
        registration = register_response.json()
        self.assertEqual(registration["user"]["email"], "runner@example.com")
        self.assertEqual(registration["user"]["first_name"], "Alex")
        self.assertNotIn("password_hash", registration["user"])
        self.assertEqual(registration["token_type"], "bearer")

        duplicate_response = await self.client.post(
            "/register",
            json={
                "email": "runner@example.com",
                "password": "safe-password-123",
                "first_name": "Alex",
                "last_name": "Runner",
            },
        )
        self.assertEqual(duplicate_response.status_code, 409)

        login_response = await self.client.post(
            "/login",
            json={
                "email": "RUNNER@example.com",
                "password": "safe-password-123",
            },
        )
        self.assertEqual(login_response.status_code, 200)
        token = login_response.json()["token"]
        profile_response = await self.client.get(
            "/api/v1/profile",
            headers={"Authorization": f"Bearer {token}"},
        )
        self.assertEqual(profile_response.status_code, 200)
        profile = profile_response.json()["user"]
        self.assertEqual(profile["email"], "runner@example.com")
        self.assertEqual(profile["available_training_days"], [])

        updated_profile = await self.client.patch(
            "/api/v1/profile",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "goal": "10K",
                "experience_level": "intermediate",
                "weekly_mileage_km": 24.5,
                "max_hr": 188,
                "age": 34,
                "available_training_days": ["mon", "wed", "sat"],
            },
        )
        self.assertEqual(updated_profile.status_code, 200)
        updated_user = updated_profile.json()["user"]
        self.assertEqual(updated_user["goal"], "10K")
        self.assertEqual(updated_user["experience_level"], "intermediate")
        self.assertEqual(updated_user["weekly_mileage_km"], 24.5)
        self.assertEqual(updated_user["max_hr"], 188)
        self.assertEqual(updated_user["age"], 34)
        self.assertEqual(updated_user["available_training_days"], ["mon", "wed", "sat"])

        self.client.headers["Authorization"] = f"Bearer {token}"
        zones_response = await self.client.get("/api/v1/heart-rate-zones")
        self.assertEqual(zones_response.status_code, 200, zones_response.text)
        zones_body = zones_response.json()
        self.assertEqual(zones_body["max_hr"], 188)
        self.assertEqual(zones_body["age"], 34)
        self.assertEqual(
            zones_body["zones"],
            [
                {"zone": "Z1 Very Light", "min_bpm": 94, "max_bpm": 112},
                {"zone": "Z2 Light", "min_bpm": 112, "max_bpm": 131},
                {"zone": "Z3 Moderate", "min_bpm": 131, "max_bpm": 150},
                {"zone": "Z4 Hard", "min_bpm": 150, "max_bpm": 169},
                {"zone": "Z5 Maximum", "min_bpm": 169, "max_bpm": 188},
            ],
        )

        with (
            patch(
                "runcoach_ai.main.analyze_run_metrics",
                return_value=RuleEngineResult(
                    pace_formatted="6:00",
                    training_load=150,
                    intensity_zone="Easy/Aerobic",
                    base_recommendation="Base Aerobic Run",
                ),
            ) as analyze,
            patch(
                "runcoach_ai.main.generate_coach_feedback",
                new_callable=AsyncMock,
                return_value="Good work. Keep your next run comfortable.",
            ) as feedback,
        ):
            analysis_response = await self.client.post(
                "/api/v1/analyze_run",
                headers={"Authorization": f"Bearer {token}"},
                json={
                    "distance_km": 5,
                    "time_seconds": 1800,
                    "avg_hr": 140,
                    "rpe": 5,
                },
            )

        self.assertEqual(analysis_response.status_code, 200)
        self.assertEqual(analyze.call_args.kwargs, {"max_hr": 188})
        feedback_run_data = feedback.call_args.args[0]
        self.assertEqual(
            feedback_run_data["runner_profile"],
            {
                "goal": "10K",
                "experience_level": "intermediate",
                "weekly_mileage_km": 24.5,
                "max_hr": 188,
                "available_training_days": ["mon", "wed", "sat"],
            },
        )

        invalid_login = await self.client.post(
            "/api/v1/auth/login",
            json={"email": "runner@example.com", "password": "wrong-password"},
        )
        self.assertEqual(invalid_login.status_code, 401)
        unauthenticated_profile = await self.client.get(
            "/api/v1/profile",
            headers={"Authorization": "Bearer invalid"},
        )
        self.assertEqual(unauthenticated_profile.status_code, 401)
        unauthenticated_zones = await self.client.get(
            "/api/v1/heart-rate-zones",
            headers={"Authorization": "invalid"},
        )
        self.assertEqual(unauthenticated_zones.status_code, 401)

    async def test_runs_are_scoped_to_authenticated_user_and_include_recovery(self) -> None:
        registration = await self.client.post(
            "/api/v1/auth/register",
            json={
                "email": "another-runner@example.com",
                "password": "secure-password-456",
                "first_name": "Sam",
                "last_name": "Runner",
            },
        )
        runner_token = registration.json()["token"]
        runner_headers = {"Authorization": f"Bearer {runner_token}"}
        with patch(
            "runcoach_ai.main.generate_coach_feedback",
            new_callable=AsyncMock,
            return_value="Recover well before the next run.",
        ) as feedback:
            analyzed = await self.client.post(
                "/api/v1/analyze_run",
                headers=runner_headers,
                json={
                    "distance_km": 5,
                    "time_seconds": 1800,
                    "avg_hr": 140,
                    "rpe": 5,
                    "sleep_hours": 4.5,
                    "resting_hr": 61,
                },
            )

        self.assertEqual(analyzed.status_code, 200)
        self.assertEqual(
            analyzed.json()["recommendation"],
            "Recovery Run or Rest Day",
        )
        self.assertEqual(
            feedback.call_args.args[0]["sleep_hours"],
            4.5,
        )
        runner_history = await self.client.get(
            "/api/v1/runs",
            headers=runner_headers,
        )
        self.assertEqual(runner_history.status_code, 200)
        self.assertEqual(runner_history.json()["runs"][0]["sleep_hours"], 4.5)
        self.assertEqual(runner_history.json()["runs"][0]["resting_hr"], 61)

        original_user_history = await self.client.get("/api/v1/runs")
        self.assertEqual(original_user_history.status_code, 200)
        self.assertEqual(original_user_history.json()["runs"], [])
        unauthenticated_runs = await self.client.get(
            "/api/v1/runs",
            headers={"Authorization": "Bearer invalid"},
        )
        self.assertEqual(unauthenticated_runs.status_code, 401)

    async def test_weather_endpoint_returns_localized_forecast_and_advice(self) -> None:
        weather = {
            "location": {"latitude": 43.2, "longitude": 76.9, "timezone": "Asia/Almaty"},
            "current": {
                "temperature_c": 12.0,
                "feels_like_c": 11.0,
                "relative_humidity": 60,
                "precipitation_mm": 0.0,
                "wind_speed_kmh": 8.0,
                "weather_code": 1,
                "description": "Ясно",
            },
            "forecast": {
                "date": "2026-10-03",
                "temperature_min_c": 8.0,
                "temperature_max_c": 16.0,
                "precipitation_probability": 10,
                "weather_code": 1,
                "description": "Ясно",
            },
        }
        with (
            patch("runcoach_ai.main.fetch_weather", new_callable=AsyncMock, return_value=weather),
            patch(
                "runcoach_ai.main.generate_clothing_advice",
                new_callable=AsyncMock,
                return_value="Наденьте лёгкую куртку.",
            ) as advice,
        ):
            response = await self.client.post(
                "/api/v1/weather",
                json={"latitude": 43.2, "longitude": 76.9, "lang": "ru"},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["current"]["description"], "Ясно")
        self.assertEqual(
            response.json()["clothing_recommendation"],
            "Наденьте лёгкую куртку.",
        )
        advice.assert_awaited_once_with(weather["current"], "ru")


if __name__ == "__main__":
    unittest.main()
