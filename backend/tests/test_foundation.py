import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, patch

from sqlalchemy import inspect
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.orm import configure_mappers

from runcoach_ai import models
from runcoach_ai.database import Base, add_missing_run_columns, normalize_database_url
from runcoach_ai.main import app, lifespan, root


class ModelTests(unittest.TestCase):
    def test_normalizes_cloud_database_urls_to_async_drivers(self) -> None:
        self.assertEqual(
            normalize_database_url("postgres://runner:secret@db.example.com/runcoach"),
            "postgresql+asyncpg://runner:secret@db.example.com/runcoach",
        )
        self.assertEqual(
            normalize_database_url("postgresql://runner@db.example.com/runcoach"),
            "postgresql+asyncpg://runner@db.example.com/runcoach",
        )
        self.assertEqual(
            normalize_database_url("sqlite:///./runcoach.db"),
            "sqlite+aiosqlite:///./runcoach.db",
        )

    def test_models_register_expected_tables_and_constraints(self) -> None:
        configure_mappers()

        self.assertEqual(
            set(Base.metadata.tables),
            {"users", "runs", "run_analyses", "recommendations"},
        )
        self.assertTrue(models.RunAnalysis.__table__.c.run_id.unique)
        self.assertIn(
            "rpe BETWEEN 1 AND 10",
            {
                str(constraint.sqltext)
                for constraint in models.Run.__table__.constraints
                if constraint.name == "check_run_rpe_range"
            },
        )


class ApplicationTests(unittest.IsolatedAsyncioTestCase):
    async def test_root_returns_service_message(self) -> None:
        self.assertEqual(await root(), {"message": "RunCoach AI API"})

    async def test_lifespan_creates_tables_and_disposes_engine(self) -> None:
        connection = AsyncMock()

        class BeginContext:
            async def __aenter__(self):
                return connection

            async def __aexit__(self, exc_type, exc_value, traceback):
                return False

        mocked_engine = SimpleNamespace(
            begin=Mock(return_value=BeginContext()),
            dispose=AsyncMock(),
        )
        with patch("runcoach_ai.main.engine", mocked_engine):
            async with lifespan(app):
                pass

        mocked_engine.begin.assert_called_once_with()
        self.assertEqual(connection.run_sync.await_count, 2)
        connection.run_sync.assert_any_await(Base.metadata.create_all)
        connection.run_sync.assert_any_await(add_missing_run_columns)
        mocked_engine.dispose.assert_awaited_once()

    async def test_lifespan_creates_tables_in_sqlite(self) -> None:
        sqlite_engine = create_async_engine("sqlite+aiosqlite:///:memory:")
        try:
            with patch("runcoach_ai.main.engine", sqlite_engine):
                async with lifespan(app):
                    async with sqlite_engine.connect() as connection:
                        table_names = await connection.run_sync(
                            lambda sync_connection: inspect(sync_connection).get_table_names()
                        )

            self.assertEqual(
                set(table_names),
                {"users", "runs", "run_analyses", "recommendations"},
            )
        finally:
            await sqlite_engine.dispose()

    async def test_additive_run_schema_migration(self) -> None:
        sqlite_engine = create_async_engine("sqlite+aiosqlite:///:memory:")
        try:
            async with sqlite_engine.begin() as connection:
                await connection.exec_driver_sql(
                    "CREATE TABLE runs (id INTEGER PRIMARY KEY)"
                )
                await connection.exec_driver_sql(
                    "CREATE TABLE run_analyses (id INTEGER PRIMARY KEY)"
                )
                await connection.exec_driver_sql(
                    "CREATE TABLE users (id INTEGER PRIMARY KEY, email VARCHAR(255))"
                )
                await connection.run_sync(add_missing_run_columns)
                run_columns = await connection.run_sync(
                    lambda sync_connection: {
                        column["name"]
                        for column in inspect(sync_connection).get_columns("runs")
                    }
                )
                analysis_columns = await connection.run_sync(
                    lambda sync_connection: {
                        column["name"]
                        for column in inspect(sync_connection).get_columns("run_analyses")
                    }
                )
                user_columns = await connection.run_sync(
                    lambda sync_connection: {
                        column["name"]
                        for column in inspect(sync_connection).get_columns("users")
                    }
                )

            self.assertIn("pace_formatted", run_columns)
            self.assertIn("sleep_hours", run_columns)
            self.assertIn("resting_hr", run_columns)
            self.assertIn("base_recommendation", analysis_columns)
            self.assertIn("password_hash", user_columns)
            self.assertIn("first_name", user_columns)
            self.assertIn("goal", user_columns)
            self.assertIn("experience_level", user_columns)
            self.assertIn("weekly_mileage_km", user_columns)
            self.assertIn("max_hr", user_columns)
            self.assertIn("age", user_columns)
            self.assertIn("available_training_days", user_columns)
            self.assertIn("is_active", user_columns)
        finally:
            await sqlite_engine.dispose()


if __name__ == "__main__":
    unittest.main()
