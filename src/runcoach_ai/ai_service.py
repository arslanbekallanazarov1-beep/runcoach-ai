"""LLM-backed explanations for metrics already calculated by the rule engine."""

import json
import logging
import os
import re
from typing import Any

import httpx
from pydantic import BaseModel, Field, ValidationError


OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
DEFAULT_MODEL = "google/gemini-2.0-flash-001"
REQUEST_TIMEOUT_SECONDS = 20.0
PLAN_REQUEST_TIMEOUT_SECONDS = 90.0

SYSTEM_PROMPT = """You are a supportive running coach for beginner runners.
Follow these rules strictly:
1. Respond with exactly 2-3 short sentences.
2. Never hallucinate or invent metrics. Only reference data provided in the
   user's message. If a detail is not provided, do not mention it.
3. Explain the provided base_recommendation in a friendly, encouraging way.
4. Do not change, replace, or add to the base_recommendation.
5. Return all prose, intensity descriptions, and recommendation descriptions in
   the exact language requested in the user's message ("en" or "ru"). Do not
   mix languages. Keep numerical values and units unchanged.
6. Never copy an English category name into a Russian response. Translate every
   category and recommendation label into the requested language."""

PLAN_SYSTEM_PROMPT = """You are an experienced, safety-conscious running coach.
Return only a valid JSON object with exactly these keys:
{"title": string, "overview": string, "weeks": [{"week": integer,
"focus": string, "workouts": [{"day": string, "title": string,
"description": string, "duration_minutes": integer}]}]}.
Create one week per requested week, numbered consecutively from 1. Use only
the requested language for every human-readable string; "en" means English
and "ru" means Russian. Make the plan gradual and appropriate for the stated
fitness level and goal. Include at least 3 recovery-aware workouts per week.
Do not promise a result or prescribe training through pain. Do not include
Markdown fences or any text outside the JSON object."""

WEATHER_SYSTEM_PROMPT = """You are a practical running gear advisor.
Recommend clothing for one run using only the supplied weather conditions.
In thunderstorms, advise moving the run indoors or postponing. Keep the
recommendation concise, actionable, and entirely in the requested language
("en" or "ru"). Do not invent weather measurements."""

logger = logging.getLogger(__name__)


def _fallback(base_recommendation: str) -> str:
    return (
        "Great effort on your run! Based on your metrics, your next session "
        f"should be: {base_recommendation}."
    )


def localize_analysis_labels(
    intensity_zone: str,
    recommendation: str,
    language: str,
) -> tuple[str, str]:
    """Translate presentation labels; deterministic source values remain intact."""
    intensity_labels = {
        "Easy/Aerobic": "Лёгкая / аэробная",
        "Moderate/Threshold": "Умеренная / пороговая",
        "Hard/Anaerobic": "Высокая / анаэробная",
    }
    recommendation_labels = {
        "Recovery Run or Rest Day": "Восстановительная пробежка или отдых",
        "Progression or Interval Run": "Прогрессивная или интервальная пробежка",
        "Base Aerobic Run": "Базовая аэробная пробежка",
    }
    if language == "ru":
        return (
            intensity_labels.get(intensity_zone, intensity_zone),
            recommendation_labels.get(recommendation, recommendation),
        )
    return intensity_zone, recommendation


async def _openrouter_completion(
    messages: list[dict[str, str]],
    *,
    timeout_seconds: float = REQUEST_TIMEOUT_SECONDS,
) -> str:
    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        raise AIServiceUnavailable(
            "OPENROUTER_API_KEY is not configured",
            code="plan_ai_not_configured",
        )

    payload = {
        "model": os.getenv("LLM_MODEL", DEFAULT_MODEL),
        "messages": messages,
        "temperature": 0.4,
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    async with httpx.AsyncClient(timeout=timeout_seconds) as client:
        response = await client.post(OPENROUTER_URL, headers=headers, json=payload)
    response.raise_for_status()
    response_data = response.json()
    content = response_data["choices"][0]["message"]["content"]
    if not isinstance(content, str) or not content.strip():
        raise ValueError("OpenRouter response contained no content")
    return content.strip()


class AIServiceUnavailable(Exception):
    """The configured AI provider could not produce a response."""

    def __init__(
        self,
        message: str,
        *,
        code: str = "plan_generation_unavailable",
    ) -> None:
        super().__init__(message)
        self.code = code


class PlanWorkout(BaseModel):
    day: str = Field(min_length=1, max_length=40)
    title: str = Field(min_length=1, max_length=100)
    description: str = Field(min_length=1, max_length=500)
    duration_minutes: int = Field(ge=1, le=600)


class PlanWeek(BaseModel):
    week: int = Field(ge=1, le=52)
    focus: str = Field(min_length=1, max_length=200)
    workouts: list[PlanWorkout] = Field(min_length=3, max_length=14)


class TrainingPlan(BaseModel):
    title: str = Field(min_length=1, max_length=160)
    overview: str = Field(min_length=1, max_length=1000)
    weeks: list[PlanWeek] = Field(min_length=1, max_length=52)


def _parse_training_plan_json(content: str) -> TrainingPlan:
    """Parse and validate a plan from plain, fenced, or wrapped JSON output."""
    decoder = json.JSONDecoder()
    fenced_blocks = re.findall(
        r"```(?:\s*json)?\s*(.*?)\s*```",
        content,
        flags=re.IGNORECASE | re.DOTALL,
    )
    candidates = list(dict.fromkeys([*fenced_blocks, content.strip()]))
    validation_error: ValidationError | None = None

    def validate_nested(value: Any) -> TrainingPlan | None:
        nonlocal validation_error
        if isinstance(value, dict):
            try:
                return TrainingPlan.model_validate(value)
            except ValidationError as error:
                if validation_error is None:
                    validation_error = error
            for nested_value in value.values():
                plan = validate_nested(nested_value)
                if plan is not None:
                    return plan
        elif isinstance(value, list):
            for nested_value in value:
                plan = validate_nested(nested_value)
                if plan is not None:
                    return plan
        return None

    for candidate in candidates:
        for offset, character in enumerate(candidate):
            if character != "{":
                continue
            try:
                value, _ = decoder.raw_decode(candidate, offset)
            except json.JSONDecodeError:
                continue
            plan = validate_nested(value)
            if plan is not None:
                return plan

    if validation_error is not None:
        raise validation_error
    raise ValueError(
        "Training plan response did not contain a valid JSON object. "
        "Expected JSON with 'title', 'overview', and 'weeks' fields."
    )


async def generate_coach_feedback(
    run_data: dict[str, Any],
    engine_result: dict[str, Any],
    language: str = "en",
) -> str:
    """Explain run metrics and deterministic guidance using OpenRouter.

    The LLM is only asked to explain metrics and the recommendation already
    produced by the rule engine; it must not make training decisions.
    """
    recommendation = engine_result.get("base_recommendation")
    if not isinstance(recommendation, str) or not recommendation.strip():
        logger.warning("Cannot generate coaching feedback without a base recommendation")
        return _fallback("a suitable next session")

    fallback = _fallback(recommendation)
    prompt_intensity, prompt_recommendation = localize_analysis_labels(
        str(engine_result.get("intensity_zone", "")),
        recommendation,
        language,
    )
    if language == "ru":
        fallback = (
            "Отличная работа на пробежке! По вашим показателям следующей "
            f"тренировкой должна быть: {prompt_recommendation}."
        )
    request_data = json.dumps(
        {
            "run_data": run_data,
            "engine_result": {
                **engine_result,
                "intensity_zone": prompt_intensity,
                "base_recommendation": prompt_recommendation,
            },
            "language": language,
        },
        ensure_ascii=False,
    )
    try:
        return await _openrouter_completion([
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": request_data},
        ])
    except httpx.HTTPError:
        logger.exception("OpenRouter request failed; using deterministic feedback fallback")
    except AIServiceUnavailable:
        logger.warning("OPENROUTER_API_KEY is not configured; using feedback fallback")
    except (KeyError, IndexError, TypeError, ValueError):
        logger.exception("OpenRouter returned an invalid response; using feedback fallback")
    except Exception:
        logger.exception("Unexpected error generating coaching feedback; using fallback")

    return fallback


async def generate_training_plan(
    goal: str,
    fitness_level: str,
    timeline_weeks: int,
    language: str,
) -> TrainingPlan:
    """Generate a personalized training plan using the LLM.

    The plan is validated for proper structure (consecutive weeks) and returned
    as a TrainingPlan object. All errors are wrapped in AIServiceUnavailable
    with specific error codes for better client handling.

    Args:
        goal: The user's running goal (e.g., "5K race", "half marathon")
        fitness_level: The user's fitness level ("beginner", "intermediate", "advanced")
        timeline_weeks: Number of weeks in the plan (1-52)
        language: Language for the plan ("en" or "ru")

    Returns:
        TrainingPlan: A validated training plan object

    Raises:
        AIServiceUnavailable: If the AI provider is unavailable or returns invalid data
    """
    request_data = json.dumps(
        {
            "goal": goal,
            "fitness_level": fitness_level,
            "timeline_weeks": timeline_weeks,
            "language": language,
        },
        ensure_ascii=False,
    )
    try:
        content = await _openrouter_completion(
            [
                {"role": "system", "content": PLAN_SYSTEM_PROMPT},
                {"role": "user", "content": request_data},
            ],
            timeout_seconds=PLAN_REQUEST_TIMEOUT_SECONDS,
        )
        plan = _parse_training_plan_json(content)

        # Validate that the plan contains the correct number of consecutive weeks
        expected_weeks = list(range(1, timeline_weeks + 1))
        generated_weeks = [week.week for week in plan.weeks]
        if generated_weeks != expected_weeks:
            raise ValueError(
                f"Generated plan must include consecutive requested weeks. "
                f"Expected weeks {expected_weeks}, but got {generated_weeks}"
            )

        # Additional validation: ensure each week has at least 3 workouts
        for week in plan.weeks:
            if len(week.workouts) < 3:
                raise ValueError(
                    f"Generated plan for week {week.week} must have at least 3 workouts, "
                    f"but got {len(week.workouts)}"
                )

        logger.info(
            f"Successfully generated training plan for {goal} ({fitness_level}), "
            f"{timeline_weeks} weeks in {language}"
        )
        return plan

    except AIServiceUnavailable:
        logger.exception("Training plan generation is unavailable")
        raise

    except httpx.TimeoutException as error:
        logger.exception("AI provider timed out while generating training plan")
        raise AIServiceUnavailable(
            "AI provider timed out while generating training plan",
            code="plan_ai_timeout",
        ) from error

    except httpx.HTTPStatusError as error:
        logger.exception("AI provider returned an error while generating training plan")
        raise AIServiceUnavailable(
            "AI provider returned an unsuccessful response",
            code="plan_ai_provider_error",
        ) from error

    except httpx.HTTPError as error:
        logger.exception("AI provider request failed while generating training plan")
        raise AIServiceUnavailable(
            "AI provider request failed while generating training plan",
            code="plan_ai_provider_error",
        ) from error

    except (KeyError, IndexError, TypeError, ValueError, ValidationError) as error:
        logger.exception(
            f"Could not generate a valid training plan: {error}. "
            "The LLM response may be malformed or invalid."
        )
        raise AIServiceUnavailable(
            f"Could not generate a valid training plan: {error}",
            code="plan_invalid_response",
        ) from error


async def generate_clothing_advice(
    current_weather: dict[str, Any],
    language: str,
) -> str:
    from .weather_service import fallback_clothing_recommendation

    fallback = fallback_clothing_recommendation(
        float(current_weather["temperature_c"]),
        int(current_weather["weather_code"]),
        language,
    )
    try:
        return await _openrouter_completion([
            {"role": "system", "content": WEATHER_SYSTEM_PROMPT},
            {
                "role": "user",
                "content": json.dumps(
                    {"weather": current_weather, "language": language},
                    ensure_ascii=False,
                ),
            },
        ])
    except httpx.HTTPError:
        logger.exception("OpenRouter weather advice request failed; using rule-based advice")
    except AIServiceUnavailable:
        logger.warning("OPENROUTER_API_KEY is not configured; using weather advice fallback")
    except (KeyError, IndexError, TypeError, ValueError):
        logger.exception("OpenRouter returned invalid weather advice; using fallback")
    return fallback
