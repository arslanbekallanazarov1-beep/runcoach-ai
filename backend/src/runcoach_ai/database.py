import os

from sqlalchemy import inspect, make_url, text
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase


def normalize_database_url(database_url: str) -> str:
    """Select async drivers for common cloud-provided database URLs."""
    url = make_url(database_url.strip())
    if url.drivername in {"postgres", "postgresql"}:
        url = url.set(drivername="postgresql+asyncpg")
    elif url.drivername == "sqlite":
        url = url.set(drivername="sqlite+aiosqlite")
    return url.render_as_string(hide_password=False)


DATABASE_URL = normalize_database_url(
    os.getenv("DATABASE_URL") or "sqlite+aiosqlite:///./runcoach.db"
)
engine = create_async_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def add_missing_run_columns(connection: Connection) -> None:
    """Add profile and run columns to databases created by earlier MVP versions."""
    inspector = inspect(connection)
    tables = set(inspector.get_table_names())

    if "users" in tables:
        user_columns = {column["name"] for column in inspector.get_columns("users")}
        user_additions = {
            "password_hash": "VARCHAR(255)",
            "first_name": "VARCHAR(50)",
            "last_name": "VARCHAR(50)",
            "goal": "VARCHAR(80)",
            "experience_level": "VARCHAR(40)",
            "weekly_mileage_km": "FLOAT",
            "max_hr": "INTEGER",
            "age": "INTEGER",
            "available_training_days": "VARCHAR(80)",
            "is_active": "BOOLEAN NOT NULL DEFAULT TRUE",
        }
        for column, definition in user_additions.items():
            if column not in user_columns:
                connection.execute(
                    text(f"ALTER TABLE users ADD COLUMN {column} {definition}")
                )

    if "runs" not in inspector.get_table_names():
        return

    run_columns = {column["name"] for column in inspector.get_columns("runs")}
    run_additions = {
        "pace_formatted": "VARCHAR(10)",
        "sleep_hours": "FLOAT",
        "resting_hr": "INTEGER",
    }
    for column, definition in run_additions.items():
        if column not in run_columns:
            connection.execute(
                text(f"ALTER TABLE runs ADD COLUMN {column} {definition}")
            )

    if "run_analyses" in tables:
        analysis_columns = {
            column["name"] for column in inspector.get_columns("run_analyses")
        }
        if "base_recommendation" not in analysis_columns:
            connection.execute(
                text("ALTER TABLE run_analyses ADD COLUMN base_recommendation VARCHAR(100)")
            )
