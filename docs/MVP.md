# MVP - Minimum Viable Product Documentation

## Overview
MVP is designed to be as simple and fast as possible while supporting the main user cycle without unnecessary complexity.

## Technical Constraints
1. One developer
2. Minimal dependencies
3. No microservices
4. No Kubernetes
5. No complex infrastructure
6. Backend: Python + FastAPI
7. Mobile: Flutter
8. Database: PostgreSQL
9. Deterministic rules are authoritative for run analysis; AI explains results
   and can generate on-demand training-plan drafts
10. Android first; Flutter Web and mobile clients share the API contract
11. No GPS tracking
12. No third-party integrations (Strava, Garmin, Apple Health)
13. No social feed, follows, or third-party integrations; challenge and virtual
    pacemaker UI remains an inactive local prototype
14. No separate AI chat
15. No functions outside main user cycle
16. Keep dependency additions minimal and directly tied to requested features
17. Backend features stay within the documented API scope
18. Flutter features stay within the documented user workflows
19. Weather uses the Open-Meteo forecast API; no other external data
    integrations
20. No Docker Compose, orchestration, or CI/CD; a single Docker image may be
    used for the requested cloud deployment

## Core MVP Functions
### 1. User Authentication
- User registration
- User login
- Profile management
- JWT-backed account sessions and per-user run history

### 2. Runner Profile
- Basic profile information
- Training goals (5K / 10K / Half Marathon / General Fitness)
- Weekly training target

### 3. Training Management
- Add new training sessions with:
  - Distance (km)
  - Duration (minutes)
  - Pace (minutes per km)
  - Average heart rate
  - Maximum heart rate
  - RPE (1-10 scale)
  - Sleep duration
  - Resting heart rate
  - Notes

### 4. Analysis and Recommendations
- Automatic training analysis using deterministic rules
- AI explanation and personalization of results
- Recommendation for next training

### 5. Training History
- View all training sessions
- Basic progress analytics

## Supporting Runner Features
- Generate an optional structured, week-by-week AI training plan in English or
  Russian, with the rule engine remaining authoritative for run analysis.
- Track mileage by shoe pair locally; record the selected pair's distance after
  a run is successfully analyzed and show a deterministic wear alert above
  700 km.
- Estimate 5K, 10K, half-marathon, and marathon finish times from a recent run
  with the Riegel formula.
- Let runners request spoken pace and coaching feedback in English or Russian
  using platform text-to-speech.
- Show localized current weather, today's forecast, and clothing suggestions
  from Open-Meteo and optional LLM advice.
- Send a user-triggered local morning briefing; browser notifications are not
  scheduled automatically.
- Store challenge and pacemaker-duel placeholder models/UI without tracking,
  competitions, or server persistence.

## MVP Limitations
- Android first; the requested account, weather, plan, and notification
  surfaces also support Flutter Web
- Manual distance input
- No third-party integrations
- No social feed, follows, or active competitions
- No AI chat
- Deterministic rules for core training decisions
- AI never overrides deterministic run-analysis metrics or recommendations.
- Gear mileage and shoe selection are stored on the device and are not synced
  to the backend.
- Race finish times are estimates based on a single recent run, not guarantees.
- Low sleep (<5 hours) or high resting heart rate (>=100 bpm) switches the
  deterministic next-session guidance to recovery or rest.

## Development Priorities
1. Fast implementation of main user cycle
2. Minimal dependencies
3. Simple code and architecture
4. Component testing
5. Gradual feature expansion