from contextlib import asynccontextmanager
from datetime import datetime, timezone
import os
import re
from typing import AsyncIterator, Literal
from uuid import UUID

from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import httpx
from pydantic import AliasChoices, BaseModel, Field, field_validator
from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from .ai_service import (
    AIServiceUnavailable,
    TrainingPlan,
    generate_clothing_advice,
    generate_coach_feedback,
    generate_training_plan,
    localize_analysis_labels,
)
from .auth_service import create_access_token, decode_access_token, hash_password, verify_password
from .database import Base, SessionLocal, add_missing_run_columns, engine
from .models import Run, RunAnalysis, User
from .heart_rate import calculate_heart_rate_zones
from .rule_engine import RunInput, analyze_run_metrics
from .weather_service import fetch_weather


bearer_scheme = HTTPBearer(auto_error=False)


class TrainingPlanRequest(BaseModel):
    goal: str = Field(min_length=2, max_length=160)
    fitness_level: str = Field(min_length=2, max_length=80)
    timeline_weeks: int = Field(
        ge=1,
        le=52,
        validation_alias=AliasChoices("timeline_weeks", "weeks"),
    )
    language: Literal["en", "ru"] = Field(
        default="en",
        validation_alias=AliasChoices("language", "lang"),
    )


class RegisterRequest(BaseModel):
    email: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=8, max_length=128)
    first_name: str = Field(min_length=1, max_length=50)
    last_name: str = Field(min_length=1, max_length=50)

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str) -> str:
        email = value.strip().lower()
        if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
            raise ValueError("Enter a valid email address.")
        return email

    @field_validator("first_name", "last_name")
    @classmethod
    def trim_name(cls, value: str) -> str:
        name = value.strip()
        if not name:
            raise ValueError("Name cannot be blank.")
        return name


class LoginRequest(BaseModel):
    email: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=1, max_length=128)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        email = value.strip().lower()
        if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
            raise ValueError("Enter a valid email address.")
        return email


class WeatherRequest(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    language: Literal["en", "ru"] = Field(
        default="en",
        validation_alias=AliasChoices("language", "lang"),
    )


class ProfileUpdateRequest(BaseModel):
    first_name: str | None = Field(default=None, min_length=1, max_length=50)
    last_name: str | None = Field(default=None, min_length=1, max_length=50)
    goal: str | None = Field(default=None, min_length=2, max_length=80)
    experience_level: Literal["beginner", "intermediate", "advanced"] | None = None
    weekly_mileage_km: float | None = Field(default=None, ge=0, le=300)
    max_hr: int | None = Field(default=None, ge=120, le=240)
    age: int | None = Field(default=None, ge=10, le=120)
    available_training_days: list[
        Literal["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    ] | None = Field(default=None, min_length=1, max_length=7)

    @field_validator("first_name", "last_name", "goal")
    @classmethod
    def trim_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("Value cannot be blank.")
        return trimmed

    @field_validator("available_training_days")
    @classmethod
    def deduplicate_training_days(
        cls,
        value: list[str] | None,
    ) -> list[str] | None:
        if value is None:
            return None
        deduplicated = list(dict.fromkeys(value))
        if not deduplicated:
            raise ValueError("Choose at least one training day.")
        return deduplicated


async def get_session() -> AsyncIterator[AsyncSession]:
    async with SessionLocal() as session:
        yield session


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    session: AsyncSession = Depends(get_session),
) -> User:
    if credentials is None:
        raise HTTPException(status_code=401, detail="Authentication required.")
    payload = decode_access_token(credentials.credentials)
    if payload is None:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired access token.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    try:
        user_id = UUID(payload["sub"])
    except ValueError as error:
        raise HTTPException(status_code=401, detail="Invalid access token.") from error
    user = await session.get(User, user_id)
    if user is None or not user.is_active:
        raise HTTPException(status_code=401, detail="User account is unavailable.")
    return user


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
        await connection.run_sync(add_missing_run_columns)
    yield
    await engine.dispose()


def _allowed_cors_origins() -> list[str]:
    configured = os.getenv("CORS_ALLOW_ORIGINS")
    if configured:
        return [origin.strip() for origin in configured.split(",") if origin.strip()]
    return [
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:8000",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5173",
        "http://127.0.0.1:8000",
    ]


app = FastAPI(title="RunCoach AI", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_cors_origins(),
    allow_origin_regex=r"^https?://(?:localhost|127\.0\.0\.1)(?::\d+)?$",
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root() -> dict[str, str]:
    return {"message": "RunCoach AI API"}


@app.post("/api/v1/analyze_run")
@app.post("/api/v1/runs")
async def analyze_run(
    data: RunInput,
    lang: Literal["en", "ru"] = Query(default="en"),
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> dict[str, object]:
    engine_result = analyze_run_metrics(data, max_hr=user.max_hr or 195)
    run_data = data.model_dump(exclude_none=True)
    profile_context = _profile_payload(user)
    runner_profile = {
        key: value
        for key, value in profile_context.items()
        if key
        in {
            "goal",
            "experience_level",
            "weekly_mileage_km",
            "max_hr",
            "available_training_days",
        }
        and value is not None
        and value != []
    }
    if runner_profile:
        run_data["runner_profile"] = runner_profile
    engine_metrics = engine_result.model_dump()
    coach_feedback = await generate_coach_feedback(run_data, engine_metrics, lang)
    localized_intensity, localized_recommendation = localize_analysis_labels(
        engine_result.intensity_zone,
        engine_result.base_recommendation,
        lang,
    )

    run = Run(
        user_id=user.id,
        distance_km=data.distance_km,
        time_seconds=data.time_seconds,
        pace_formatted=engine_result.pace_formatted,
        avg_hr=data.avg_hr,
        rpe=data.rpe,
        sleep_hours=data.sleep_hours,
        resting_hr=data.resting_hr,
        date=datetime.now(timezone.utc),
    )
    session.add(run)
    await session.flush()
    session.add(
        RunAnalysis(
            run_id=run.id,
            training_load=engine_result.training_load,
            intensity_zone=engine_result.intensity_zone,
            base_recommendation=engine_result.base_recommendation,
            ai_explanation=coach_feedback,
        )
    )
    await session.commit()

    return {
        "id": str(run.id),
        "date": run.date.isoformat(),
        "status": "success",
        "metrics": {
            "pace": engine_result.pace_formatted,
            "training_load": engine_result.training_load,
            "intensity_zone": localized_intensity,
        },
        "recommendation": localized_recommendation,
        "coach_feedback": coach_feedback,
    }


@app.post("/api/v1/generate-plan", response_model=TrainingPlan)
@app.post("/generate-plan", response_model=TrainingPlan, include_in_schema=False)
async def create_training_plan(
    data: TrainingPlanRequest,
    lang: Literal["en", "ru"] | None = Query(default=None),
) -> TrainingPlan:
    try:
        return await generate_training_plan(
            goal=data.goal,
            fitness_level=data.fitness_level,
            timeline_weeks=data.timeline_weeks,
            language=lang or data.language,
        )
    except AIServiceUnavailable as error:
        raise HTTPException(
            status_code=503,
            detail=error.code,
        ) from error


@app.post("/api/v1/auth/register")
@app.post("/register")
async def register(data: RegisterRequest, session: AsyncSession = Depends(get_session)) -> dict[str, object]:
    existing_user = await session.scalar(select(User).where(User.email == data.email))
    if existing_user is not None:
        raise HTTPException(status_code=409, detail="An account with this email already exists.")
    user = User(
        email=data.email,
        password_hash=hash_password(data.password),
        first_name=data.first_name,
        last_name=data.last_name,
    )
    session.add(user)
    try:
        await session.commit()
    except IntegrityError as error:
        await session.rollback()
        raise HTTPException(
            status_code=409,
            detail="An account with this email already exists.",
        ) from error
    await session.refresh(user)
    return _authentication_response(user)


@app.post("/api/v1/auth/login")
@app.post("/login")
async def login(data: LoginRequest, session: AsyncSession = Depends(get_session)) -> dict[str, object]:
    user = await session.scalar(select(User).where(User.email == data.email))
    if (
        user is None
        or user.password_hash is None
        or not user.is_active
        or not verify_password(data.password, user.password_hash)
    ):
        raise HTTPException(status_code=401, detail="Email or password is incorrect.")
    return _authentication_response(user)


@app.get("/api/v1/profile")
async def get_profile(user: User = Depends(get_current_user)) -> dict[str, object]:
    return {"user": _profile_payload(user)}


@app.patch("/api/v1/profile")
async def update_profile(
    data: ProfileUpdateRequest,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> dict[str, object]:
    updates = data.model_dump(exclude_unset=True)
    if "available_training_days" in updates:
        days = updates.pop("available_training_days")
        user.available_training_days = ",".join(days) if days is not None else None
    for key, value in updates.items():
        setattr(user, key, value)
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return {"user": _profile_payload(user)}


@app.get("/api/v1/heart-rate-zones")
async def get_heart_rate_zones(
    user: User = Depends(get_current_user),
) -> dict[str, object]:
    """Calculate and return heart rate zones Z1-Z5 for the current user."""
    if user.max_hr is None:
        raise HTTPException(
            status_code=400,
            detail="Maximum heart rate not set. Please update your profile with max_hr.",
        )

    try:
        zones = calculate_heart_rate_zones(user.max_hr)
        return {
            "max_hr": user.max_hr,
            "age": user.age,
            "zones": [
                {
                    "zone": zone.zone,
                    "min_bpm": zone.min_bpm,
                    "max_bpm": zone.max_bpm,
                }
                for zone in zones
            ],
        }
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error))


def _authentication_response(user: User) -> dict[str, object]:
    return {
        "user": _profile_payload(user),
        "token": create_access_token(str(user.id), user.email),
        "token_type": "bearer",
    }


def _profile_payload(user: User) -> dict[str, object]:
    return {
        "id": str(user.id),
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "goal": user.goal,
        "experience_level": user.experience_level,
        "weekly_mileage_km": user.weekly_mileage_km,
        "max_hr": user.max_hr,
        "age": user.age,
        "available_training_days": _training_days(user.available_training_days),
    }


def _training_days(value: str | None) -> list[str]:
    if not value:
        return []
    return [day for day in value.split(",") if day]


@app.post("/api/v1/weather")
async def current_weather(data: WeatherRequest) -> dict[str, object]:
    try:
        weather = await fetch_weather(data.latitude, data.longitude, data.language)
        advice = await generate_clothing_advice(weather["current"], data.language)
    except httpx.HTTPError as error:
        raise HTTPException(
            status_code=502,
            detail="The weather service is temporarily unavailable.",
        ) from error
    except (KeyError, IndexError, TypeError, ValueError) as error:
        raise HTTPException(
            status_code=502,
            detail="The weather service returned invalid data.",
        ) from error
    return {**weather, "clothing_recommendation": advice}


@app.get("/api/v1/runs")
async def list_runs(
    limit: int = Query(default=20, ge=1, le=100),
    lang: Literal["en", "ru"] = Query(default="en"),
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> dict[str, list[dict[str, object]]]:
    statement = (
        select(Run, RunAnalysis)
        .outerjoin(RunAnalysis, RunAnalysis.run_id == Run.id)
        .where(Run.user_id == user.id)
        .order_by(Run.date.desc())
        .limit(limit)
    )
    records = (await session.execute(statement)).all()
    runs = []
    for run, analysis in records:
        metrics = analyze_run_metrics(
            RunInput(
                distance_km=run.distance_km,
                time_seconds=run.time_seconds,
                avg_hr=run.avg_hr,
                rpe=run.rpe,
                sleep_hours=run.sleep_hours,
                resting_hr=run.resting_hr,
            )
        )
        intensity = analysis.intensity_zone if analysis else metrics.intensity_zone
        recommendation = (
            analysis.base_recommendation if analysis else metrics.base_recommendation
        )
        localized_intensity, localized_recommendation = localize_analysis_labels(
            intensity,
            recommendation,
            lang,
        )
        runs.append(
            {
                "id": str(run.id),
                "date": run.date.isoformat(),
                "distance_km": run.distance_km,
                "time_seconds": run.time_seconds,
                "pace": run.pace_formatted or metrics.pace_formatted,
                "avg_hr": run.avg_hr,
                "rpe": run.rpe,
                "sleep_hours": run.sleep_hours,
                "resting_hr": run.resting_hr,
                "training_load": analysis.training_load if analysis else None,
                "intensity_zone": localized_intensity,
                "recommendation": localized_recommendation,
                "coach_feedback": analysis.ai_explanation if analysis else None,
            }
        )
    return {
        "runs": runs,
    }


@app.delete("/api/v1/runs/{run_id}")
async def delete_run(
    run_id: UUID,
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
) -> dict[str, str]:
    result = await session.execute(
        delete(Run).where(Run.id == run_id, Run.user_id == user.id)
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Run not found.")
    await session.commit()
    return {"status": "deleted"}
