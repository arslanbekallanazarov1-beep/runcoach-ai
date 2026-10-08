# API - MVP API Documentation

## Overview
REST API for mobile and Flutter Web integration with minimal endpoints to
support the main user cycle.

The backend enables local-development CORS origins and configured origins from
`CORS_ALLOW_ORIGINS`; restrict these before deploying to production. The workout
CRUD and statistics examples in the later draft sections are not implemented
routes. Current routes are documented above.

## Authentication
- Current implementation: HS256-signed bearer token, valid for 30 days. The
  client must sign in again after expiry; configure a strong `SECRET_KEY`.
- Without `SECRET_KEY`, the development server uses a temporary key and tokens
  stop working on restart.
- Method: JWT Bearer Token
- Token expires after 30 days
- Clients sign in again after expiry; automatic token refresh is not implemented.

## Core API Endpoints

### Run Analysis

#### POST /api/v1/analyze_run
Analyze submitted run metrics deterministically, then request a human-readable
explanation of the resulting metrics and recommendation.

**Request**
```json
{
  "distance_km": 5.0,
  "time_seconds": 1800,
  "avg_hr": 140,
  "rpe": 5,
  "sleep_hours": 7.5,
  "resting_hr": 58
}
```

`sleep_hours` (0 through 24) and `resting_hr` are optional. Less than five hours of sleep or
a resting heart rate of 100 bpm or higher deterministically changes the next
session guidance to recovery or rest. Recovery metrics are stored with the run
and supplied to the coach explanation.

The analysis is saved to the signed-in user's run history. Run analysis and
history requests require an access token.

**Query parameters**
- `lang`: `en` (default) or `ru`. The AI explanation is requested in this
  language, and deterministic intensity/recommendation labels are localized.
  Stored coach explanations retain the language used when the run was analyzed.

**Response**
```json
{
  "id": "run-uuid",
  "date": "2026-09-30T08:00:00+00:00",
  "status": "success",
  "metrics": {
    "pace": "6:00",
    "training_load": 150.0,
    "intensity_zone": "Easy/Aerobic"
  },
  "recommendation": "Base Aerobic Run",
  "coach_feedback": "Good work completing your run. Your next session should be a steady base aerobic run."
}
```

#### POST /api/v1/runs
Alias of `/api/v1/analyze_run`: analyze and save a run using the same request
and response format.

#### GET /api/v1/runs
Fetch saved runs, newest first. `limit` is optional (default 20, maximum 100).
`lang` is optional (`en` by default, or `ru`) and localizes deterministic
intensity and recommendation labels. Saved coach explanations retain their
original language. Requires an access token and returns only the current
user's runs.

**Response**
```json
{
  "runs": [
    {
      "id": "run-uuid",
      "date": "2026-09-30T08:00:00+00:00",
      "distance_km": 5.0,
      "time_seconds": 1860,
      "pace": "6:12",
      "avg_hr": 172,
      "rpe": 7,
      "training_load": 217.0,
      "intensity_zone": "Hard/Anaerobic",
      "recommendation": "Recovery Run or Rest Day",
      "coach_feedback": "Strong effort. Recover well before your next run."
    }
  ]
}
```

#### DELETE /api/v1/runs/{id}
Delete one saved run belonging to the authenticated user. Returns HTTP 404
when the run does not exist or belongs to another account.

**Response**
```json
{"status": "deleted"}
```

### AI Training Plan

#### POST /api/v1/generate-plan
Generate a personalized week-by-week plan. `timeline_weeks` must be between 1
and 52, and `language` must be `en` or `ru`. The same endpoint is available as
`POST /generate-plan`. Request bodies may use `timeline_weeks` or `weeks` and
`language` or `lang`; the optional `lang` query parameter takes precedence.

**Request**
```json
{
  "goal": "Almaty Half Marathon",
  "fitness_level": "beginner",
  "timeline_weeks": 12,
  "language": "en"
}
```

**Response**
```json
{
  "title": "Half Marathon Build",
  "overview": "Build endurance gradually and recover between harder sessions.",
  "weeks": [
    {
      "week": 1,
      "focus": "Easy foundation",
      "workouts": [
        {
          "day": "Monday",
          "title": "Easy run",
          "description": "Run at a conversational effort.",
          "duration_minutes": 30
        },
        {
          "day": "Wednesday",
          "title": "Steady run",
          "description": "Keep the effort comfortable and controlled.",
          "duration_minutes": 35
        },
        {
          "day": "Saturday",
          "title": "Long run",
          "description": "Build endurance at an easy pace.",
          "duration_minutes": 45
        }
      ]
    }
  ]
}
```

Each requested week is numbered consecutively and contains at least three
recovery-aware workouts. Plan generation allows the AI provider up to 90
seconds to respond. The backend accepts JSON objects in plain output, Markdown
JSON fences, or responses with surrounding prose, then validates the plan
shape and requested week sequence. A temporarily unavailable AI provider
returns HTTP 503.
Error response `detail` values distinguish missing server-side provider
configuration (`plan_ai_not_configured`), provider timeouts
(`plan_ai_timeout`), provider errors (`plan_ai_provider_error`), and invalid
generated plan data (`plan_invalid_response`).

### 1. User Authentication

#### POST /api/v1/auth/register
Create a new user account; `POST /register` is a short compatibility route.

**Request**
```json
{
  "email": "user@example.com",
  "password": "password123",
  "first_name": "John",
  "last_name": "Doe"
}
```

**Response**
```json
{
  "user": {
    "id": "user-uuid",
    "email": "user@example.com",
    "first_name": "John",
    "last_name": "Doe"
  },
  "token": "jwt-token",
  "token_type": "bearer"
}
```

#### POST /api/v1/auth/login
Authenticate an existing user; `POST /login` is a short compatibility route.

**Request**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response**
```json
{
  "user": {
    "id": "user-uuid",
    "email": "user@example.com",
    "first_name": "John",
    "last_name": "Doe"
  },
  "token": "jwt-token",
  "token_type": "bearer"
}
```

Passwords must contain at least eight characters at registration. Passwords
are stored as salted PBKDF2 hashes. Duplicate email addresses return HTTP 409;
invalid credentials return HTTP 401.

### Weather and clothing advice

#### POST /api/v1/weather
Get current weather and today's forecast from Open-Meteo, with localized
clothing advice. The service accepts latitude and longitude and requires no
weather API key.

**Request**
```json
{
  "latitude": 43.2383,
  "longitude": 76.9455,
  "language": "ru"
}
```

Use either `language` or `lang` (`en` or `ru`). The response contains
`current`, `forecast`, and `clothing_recommendation`. Clothing advice uses the
LLM when available and deterministic weather rules otherwise. Provider errors
return HTTP 502.

The Flutter app can show the dynamic morning greeting as a local notification
after user action. Web browsers do not support scheduled/repeating
notifications, so daily scheduling is not claimed.

### Local challenge prototypes

The local challenge and virtual pacemaker duel cards are Flutter placeholders;
they do not create server records, track GPS, or run competitions.

### 2. Runner Profile

#### GET /api/v1/profile
Fetch the signed-in account, including editable runner profile settings.

**Headers**
```
Authorization: Bearer <token>
```

**Response**
```json
{
  "user": {
    "id": "user-uuid",
    "first_name": "John",
    "last_name": "Doe",
    "email": "user@example.com",
    "goal": "10K",
    "experience_level": "intermediate",
    "weekly_mileage_km": 24.5,
    "max_hr": 188,
    "age": 34,
    "available_training_days": ["mon", "wed", "sat"]
  }
}
```

#### PATCH /api/v1/profile
Update any supplied user/profile fields. `max_hr` must be 120–240 bpm;
`age` must be 10–120 years. Set either field to `null` to clear it.

**Request**
```json
{
  "max_hr": 188,
  "age": 34
}
```

**Response**
```json
{
  "user": {
    "id": "user-uuid",
    "email": "user@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "max_hr": 188,
    "age": 34
  }
}
```

#### GET /api/v1/heart-rate-zones
Return the authenticated user's Z1–Z5 BPM ranges using the saved `max_hr`.
Returns HTTP 400 when no maximum heart rate is set.

```json
{
  "max_hr": 188,
  "age": 34,
  "zones": [
    {"zone": "Z1 Very Light", "min_bpm": 94, "max_bpm": 112},
    {"zone": "Z2 Light", "min_bpm": 112, "max_bpm": 131},
    {"zone": "Z3 Moderate", "min_bpm": 131, "max_bpm": 150},
    {"zone": "Z4 Hard", "min_bpm": 150, "max_bpm": 169},
    {"zone": "Z5 Maximum", "min_bpm": 169, "max_bpm": 188}
  ]
}
```

### 3. Training Sessions

#### GET /api/v1/workouts
Get list of training sessions

**Query Parameters**
```
limit: 20 (default)
offset: 0 (default)
sort: "-date" (descending by date)
```

**Response**
```json
{
  "workouts": [
    {
      "id": "workout-uuid",
      "date": "2024-01-15T08:00:00Z",
      "distance": 5.2,
      "duration": 30,
      "pace": 5.77,
      "avg_heart_rate": 145,
      "max_heart_rate": 165,
      "rpe": 7,
      "sleep_duration": 7.5,
      "notes": "Good morning run"
    }
  ],
  "pagination": {
    "limit": 20,
    "offset": 0,
    "total": 150,
    "has_more": true
  }
}
```

#### POST /api/v1/workouts
Add new training session

**Request**
```json
{
  "date": "2024-01-15T08:00:00Z",
  "distance": 5.2,
  "duration": 30,
  "pace": 5.77,
  "avg_heart_rate": 145,
  "max_heart_rate": 165,
  "rpe": 7,
  "sleep_duration": 7.5,
  "notes": "Good morning run"
}
```

**Response**
```json
{
  "workout": {
    "id": "workout-uuid",
    "date": "2024-01-15T08:00:00Z",
    "distance": 5.2,
    "duration": 30,
    "pace": 5.77,
    "avg_heart_rate": 145,
    "max_heart_rate": 165,
    "rpe": 7,
    "sleep_duration": 7.5,
    "notes": "Good morning run",
    "created_at": "2024-01-15T08:05:00Z"
  }
}
```

#### GET /api/v1/workouts/{id}
Get specific training session

**Response**
```json
{
  "workout": {
    "id": "workout-uuid",
    "date": "2024-01-15T08:00:00Z",
    "distance": 5.2,
    "duration": 30,
    "pace": 5.77,
    "avg_heart_rate": 145,
    "max_heart_rate": 165,
    "rpe": 7,
    "sleep_duration": 7.5,
    "notes": "Good morning run"
  }
}
```

#### PUT /api/v1/workouts/{id}
Update training session

**Request**
```json
{
  "distance": 5.2,
  "duration": 30,
  "pace": 5.77,
  "rpe": 8,
  "notes": "Updated notes"
}
```

**Response**
```json
{
  "workout": {
    "id": "workout-uuid",
    "distance": 5.2,
    "duration": 30,
    "pace": 5.77,
    "avg_heart_rate": 145,
    "max_heart_rate": 165,
    "rpe": 8,
    "sleep_duration": 7.5,
    "notes": "Updated notes",
    "updated_at": "2024-01-15T08:10:00Z"
  }
}
```

#### DELETE /api/v1/workouts/{id}
Delete training session

**Response**
```json
{
  "success": true,
  "message": "Training session deleted"
}
```

### 4. Analysis and Recommendations

#### POST /api/v1/workouts/analyze
Analyze training session and get recommendations

**Request**
```json
{
  "workout_id": "workout-uuid",
  "user_goal": "5K"
}
```

**Response**
```json
{
  "analysis": {
    "workout_summary": "You completed a 5.2km run in 30 minutes with an average heart rate of 145. The session was rated 7/10 on perceived exertion.",
    "intensity": "Moderate",
    "positive_points": [
      "Consistent pace throughout the run",
      "Good heart rate management",
      "Adequate recovery sleep"
    ],
    "issues": [
      "Consider adding interval training to improve speed"
    ],
    "recommendation": "Good training session. For next workout, try a tempo run at 5:30/km pace for 3km to improve your speed."
  },
  "next_workout": {
    "type": "Tempo Run",
    "distance_km": 3.0,
    "target_pace": "5:30/km",
    "goal": "Improve running speed and pace consistency"
  }
}
```

### 5. Utility Functions

#### GET /api/v1/users/stats
Get user statistics

**Query Parameters**
```
period: "week\|month\|year" (default: week)
```

**Response**
```json
{
  "stats": {
    "total_workouts": 25,
    "average_distance": 5.2,
    "average_pace": 5.77,
    "average_rpe": 7.2,
    "current_streak": 5,
    "best_pace": 5.2,
    "total_distance": 130.0,
    "weekly_average": 5.0,
    "monthly_average": 5.3
  }
}
```

#### GET /api/v1/goals
Get available training goals

**Response**
```json
{
  "goals": [
    {
      "id": "5K",
      "name": "5K",
      "description": "5 kilometer race",
      "target_pace": "5:00/km",
      "typical_weekly_distance": 8.0,
      "typical_workouts_per_week": 3
    },
    {
      "id": "10K",
      "name": "10K",
      "description": "10 kilometer race",
      "target_pace": "5:30/km",
      "typical_weekly_distance": 15.0,
      "typical_workouts_per_week": 4
    }
  ]
}
```

## Security

### Basic Security
- HTTPS required for all API calls
- JWT authentication
- Input validation for all requests
- Rate limiting: 100 requests per hour per user
- CORS restricted to frontend

### Error Handling
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Brief error description",
    "details": "Additional details (optional)",
    "field_errors": {
      "field_name": "Validation error message"
    }
  }
}
```