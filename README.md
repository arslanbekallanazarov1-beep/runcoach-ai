# RunCoach AI Backend

## Overview
FastAPI backend for account authentication, per-user run analysis/history,
recovery-aware deterministic coaching, AI training plans, and localized weather
advice.

## Architecture
- **Framework**: FastAPI
- **Database**: PostgreSQL with SQLAlchemy
- **Configuration**: Environment variables
- **Migration**: Alembic

## Features
- Registration/login with salted PBKDF2 password hashes and HS256 JWTs
- Protected run analysis, run history, and account profile endpoints
- Deterministic pace, intensity, recovery, and next-run rules
- Validated AI-generated training plans with both versioned and short routes
- Open-Meteo current conditions/forecast with localized clothing advice

## Running the Backend

### Prerequisites
- Python 3.10+
- SQLite for local development (included; no separate service required)
- PostgreSQL is optional via `DATABASE_URL`

### Installation
```bash
cd backend
pip install -r requirements.txt
```

### Environment Setup
By default, the backend uses async SQLite at `./runcoach.db` in the current
working directory. Copy `.env.example` to `.env` to make that configuration
explicit. To use PostgreSQL instead, set `DATABASE_URL` to a
`postgresql+asyncpg://` connection URL. Standard cloud `postgres://` and
`postgresql://` URLs are normalized to the async driver automatically.

### Database Setup
The MVP creates the SQLAlchemy model tables when the application starts. The
SQLite file is created automatically. When using PostgreSQL, the database itself
must already exist. Production schema changes should be managed with migrations
rather than `create_all`.

### Running
```bash
uvicorn --app-dir src runcoach_ai.main:app --host 0.0.0.0 --port 8000
```

### Root Endpoint
```bash
curl http://localhost:8000/
```

## Deterministic Rule Engine

`src/runcoach_ai/rule_engine.py` calculates pace, training load (duration in
minutes multiplied by RPE), heart-rate intensity zone, and a base next-run
recommendation using Python logic only. It does not call an LLM.

`src/runcoach_ai/ai_service.py` sends those supplied metrics and the
deterministic recommendation to OpenRouter for a human-readable explanation.
It never calculates or changes training metrics or recommendations.

Copy `.env.example` to `.env` and set `OPENROUTER_API_KEY` locally to enable
live feedback. Do not place API keys in tracked files or share them in logs.
`LLM_MODEL` optionally overrides the lightweight
`google/gemini-2.0-flash-001` default. When the key is missing or OpenRouter
fails, the service returns deterministic fallback feedback.

## Analyze Run Endpoint

`POST /api/v1/analyze_run` accepts `distance_km`, `time_seconds`, `avg_hr`,
`rpe`, and optional `sleep_hours`/`resting_hr` as JSON. A sleep duration below
five hours or resting heart rate at or above 100 bpm deterministically selects
recovery/rest guidance. It returns pace, training load, intensity zone, the
deterministic recommendation, coach feedback, and persists the run for the
authenticated user.
`POST /api/v1/runs` is an alias for the same save-and-analyze operation.
`GET /api/v1/runs?limit=20` returns the latest saved runs for that user.
Analysis and history requests accept `lang=en|ru`; localized coach
feedback is generated in the requested language and deterministic labels are
translated for display. Previously saved AI feedback remains in its original
language. Both run endpoints require `Authorization: Bearer <token>`.
`POST /api/v1/auth/register` and `/api/v1/auth/login` return user data and a
30-day JWT; short `/register` and `/login` aliases are available.

`POST /api/v1/generate-plan` (also `POST /generate-plan`) accepts `goal`,
`fitness_level`, either `timeline_weeks` or `weeks`, and either `language` or
`lang` (`en` or `ru`), with an optional `lang` query override. It returns
validated week-by-week JSON. A temporarily unavailable AI provider returns
HTTP 503.
`POST /api/v1/weather` accepts latitude/longitude and returns a localized
current forecast and clothing suggestion. Weather provider failures return
HTTP 502; AI clothing advice falls back to deterministic rules.
FastAPI `CORSMiddleware` allows local development origins on `localhost` and
`127.0.0.1` at any port, plus configured origins from `CORS_ALLOW_ORIGINS`.
Methods and headers are allowed for local Flutter Web preflight requests.
Set `CORS_ALLOW_ORIGINS` to the required trusted origins before deploying to
production.

## Cloud Deployment

The repository root `render.yaml` deploys the `backend/Dockerfile` as a
single-instance Render web service. It keeps the SQLite database on a
persistent disk at `/var/data/runcoach.db`, generates a stable `SECRET_KEY`,
and serves the platform-provided `PORT`. Set `OPENROUTER_API_KEY` in the
Render service environment to enable AI feedback and training plans; without
it, plans return HTTP 503 while run analysis continues using its deterministic
fallback feedback. For Flutter Web, set `CORS_ALLOW_ORIGINS` to the exact
deployed frontend origin(s); native Flutter clients do not require CORS.

```json
{
  "distance_km": 5.0,
  "time_seconds": 1800,
  "avg_hr": 140,
  "rpe": 5
}
```

### Running Tests
```bash
PYTHONPATH=src python -m unittest discover -s tests
```

## API Endpoints

### Root
- **GET /**
- Returns the service name.

### Run analysis and history
- **POST /api/v1/analyze_run?lang=en** - analyze and persist a run in the
  requested coach-feedback language (`en` or `ru`)
- **POST /api/v1/runs** - alias for analyze and persist
- **GET /api/v1/runs?limit=20&lang=en** - list the latest runs and coaching
  feedback, with deterministic labels localized for the request language
- **POST /api/v1/generate-plan** - generate a validated structured training
  plan; use `lang=en|ru` or the `language` JSON field

### Current API
- `/api/v1/auth/register`, `/api/v1/auth/login`
- `/api/v1/profile`
- `/api/v1/heart-rate-zones`
- `/api/v1/analyze_run`, `/api/v1/runs`
- `/api/v1/generate-plan`, `/generate-plan`
- `/api/v1/weather`

## Current Project Structure

```
backend/
├── requirements.txt
├── .env.example
└── src/
    └── runcoach_ai/
        ├── __init__.py
        ├── ai_service.py
        ├── database.py
        ├── main.py
        ├── models.py
        └── rule_engine.py
```

## Configuration

The application loads environment variables from `backend/.env` on startup.
Copy `.env.example` to `.env` and configure `SECRET_KEY` and (optionally)
`OPENROUTER_API_KEY`. The `.env` file is ignored by Git; do not commit
credentials. `LLM_MODEL` and `DATABASE_URL` are optional; the database default
is `sqlite+aiosqlite:///./runcoach.db`. Open-Meteo requires no API key.

### Required Variables
- `SECRET_KEY` is required for stable production JWTs; an ephemeral key is
  generated with a startup warning for local development when it is absent.
- `DATABASE_URL` is optional; set it to use an external database.
- `OPENROUTER_API_KEY` is optional; AI coaching/plans/advice use documented
  fallback/error behavior when unavailable.

### Example `.env`
```env
DATABASE_URL=postgresql://username:password@localhost:5432/runcoach_ai
SECRET_KEY=your-secret-key-here
DEBUG=true
```

## Database Schema

The async SQLAlchemy models store run distance, time, calculated pace, average
heart rate, RPE, and timestamp in `runs`; training load, intensity,
recommendation, and AI feedback are stored in the one-to-one `run_analyses`
table. Local development uses SQLite; PostgreSQL is available by setting
`DATABASE_URL`. Startup applies additive columns to existing local MVP
databases.

## Development

### Running Tests
```bash
PYTHONPATH=src python -m unittest discover -s tests
```

### Running Migrations
```bash
alembic upgrade head
```

### Creating New Migrations
```bash
alembic revision --autogenerate -m "migration_description"
```

## Security

### Security Considerations
- Use HTTPS in production
- Validate all API input
- Keep `SECRET_KEY` and provider API keys outside source control
- Use environment variables for secrets

### Current Security
- Protected run, history, and profile endpoints
- Account passwords use salted PBKDF2 hashes
- Wildcard CORS is for development only and must be restricted for deployment

## Current Limitations

- Profile fields are created at registration and can be edited through
  `PATCH /api/v1/profile`; general workout CRUD is not implemented.
- Training plans require a configured AI provider; unavailable providers return
  HTTP 503 rather than a fabricated plan.
- Challenge and pacemaker duel prototypes live only in Flutter and do not
  record competitions or GPS activity.

## Support

For questions and issues:
- Check documentation
- Review code
- Test endpoints
- Review error messages

## License
MIT License