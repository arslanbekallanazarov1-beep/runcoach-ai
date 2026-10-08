"""Deterministic calculations and workout guidance for recorded runs."""

from math import floor

from pydantic import BaseModel, Field


class RunInput(BaseModel):
    """Validated metrics recorded for a completed run."""

    distance_km: float = Field(gt=0)
    time_seconds: int = Field(gt=0)
    avg_hr: int = Field(gt=0)
    rpe: int = Field(ge=1, le=10)
    sleep_hours: float | None = Field(default=None, ge=0, le=24)
    resting_hr: int | None = Field(default=None, ge=30, le=240)


class RuleEngineResult(BaseModel):
    """Calculated run metrics and rule-based guidance."""

    pace_formatted: str
    training_load: float
    intensity_zone: str
    base_recommendation: str


def analyze_run_metrics(data: RunInput, max_hr: int = 195) -> RuleEngineResult:
    """Calculate pace, heart-rate zone, training load, and a base recommendation.

    Training load is the session's duration in minutes multiplied by RPE.
    Heart-rate zone boundaries use average heart rate as a percentage of max HR.
    """
    if max_hr <= 0:
        raise ValueError("max_hr must be greater than zero")

    seconds_per_km = data.time_seconds / data.distance_km
    rounded_seconds_per_km = floor(seconds_per_km + 0.5)
    pace_minutes, pace_seconds = divmod(rounded_seconds_per_km, 60)
    pace_formatted = f"{pace_minutes}:{pace_seconds:02d}"

    heart_rate_percentage = data.avg_hr / max_hr * 100
    if heart_rate_percentage < 75:
        intensity_zone = "Easy/Aerobic"
    elif heart_rate_percentage <= 88:
        intensity_zone = "Moderate/Threshold"
    else:
        intensity_zone = "Hard/Anaerobic"

    training_load = round(data.time_seconds / 60 * data.rpe, 2)

    if data.rpe >= 8 or intensity_zone == "Hard/Anaerobic":
        base_recommendation = "Recovery Run or Rest Day"
    elif data.rpe <= 4:
        base_recommendation = "Progression or Interval Run"
    else:
        base_recommendation = "Base Aerobic Run"

    if data.sleep_hours is not None and data.sleep_hours < 5:
        base_recommendation = "Recovery Run or Rest Day"
    if data.resting_hr is not None and data.resting_hr >= 100:
        base_recommendation = "Recovery Run or Rest Day"

    return RuleEngineResult(
        pace_formatted=pace_formatted,
        training_load=training_load,
        intensity_zone=intensity_zone,
        base_recommendation=base_recommendation,
    )
