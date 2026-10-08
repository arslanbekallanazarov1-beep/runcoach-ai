# Architecture - Technical Architecture Documentation

## Overview
Simple, linear architecture focused on the main user cycle. Clear separation between deterministic calculations and AI explanation.

## Main User Cycle
Run → Analyze → Understand → Next Workout → Run again

## Architecture Principles

### 1. Separation of Deterministic and AI Processing
- **Deterministic Rule Engine**: Handles objective training analysis and recommendations
- **AI Services**: Explain deterministic results and generate requested
  week-by-week training-plan drafts
- **Clear Hierarchy**: AI does not override deterministic run metrics or
  recommendations

### 2. Linear Workflow
- run → analyze → understand → next_workout → run_again
- Minimal states and transitions
- Transparent data flow between layers

### 3. Minimal Design
- One input screen (training form)
- One analysis screen (deterministic + AI explanation)
- One planning screen (next workout)
- Flat navigation structure

### 4. Layered Architecture
- **Mobile Layer**: Flutter UI components
- **Network Layer**: API client to backend
- **Business Logic Layer**: Deterministic rules and AI explanation
- **Data Layer**: Local storage and backend sync

## System Components

### Backend (Python + FastAPI)
- REST API for mobile application
- JWT registration/login and per-user access to saved run history
- Training data storage
- Deterministic rule engine
- AI explanation service
- Validated AI training-plan generation endpoint
- Open-Meteo weather endpoint and optional AI clothing advice

### Mobile (Flutter)
- UI components for each screen
- Training data input
- Local database (SQLite)
- Local shoe mileage preferences shared by Web and mobile
- Local race-time prediction using the Riegel formula
- Localized text-to-speech for coach, weather, and pace summaries
- User-triggered local morning briefing notification (Web does not schedule)
- Local challenge/pacemaker prototype UI without live competition mechanics
- Network layer integration

### Database (PostgreSQL)
- User profiles and settings
- Training session history
- Analysis results

## Analysis Flow

### Deterministic Rule Engine
Input training data → Calculate objective metrics → Generate structured analysis

**Deterministic Outputs**:
- Training intensity classification
- Detected problems/issues
- Recommended next workout type
- Recommended distance/effort levels
- Objective training guidance

**Deterministic Rule Engine uses**:
- Runner profile settings (goal, experience, weekly workouts)
- Training metrics (distance, duration, heart rate, RPE, sleep, resting heart rate)
- Predefined training rules and patterns

### AI-Explanation Layer
Takes deterministic results → Creates personalized explanation → Returns to mobile app

**AI-Explanation Capabilities**:
- Explains deterministic results in user-friendly language
- Adds context and personalization
- Makes training guidance more accessible
- Adapts explanations to user preferences

### Training Plan Generation
The plan endpoint accepts a goal, fitness level, timeline, and language and
returns validated structured JSON. Plan generation is a separate, explicit
AI workflow; run metrics and completed-run recommendations remain deterministic.

### Weather and Recovery
The weather API fetches current conditions and a daily forecast from
Open-Meteo. Clothing advice is AI-generated when configured and falls back to
deterministic temperature/condition rules. Sleep below five hours or resting
heart rate at or above 100 bpm modifies the deterministic next-run advice to
recovery/rest; the AI only explains those results.

### Complete Analysis Flow
Training Input → Deterministic Rules → Structured Analysis → AI Explanation → API Response

## Data Flow

### API Data Models
- **User**: User profile, goals, settings
- **Training**: Training session details and metrics
- **Analysis**: Deterministic analysis results
- **Explanation**: AI explanation of analysis

### Workflow
1. User adds training session (distance, duration, heart rate, RPE, sleep)
2. System runs deterministic rule engine
3. System calls AI explanation service
4. Mobile app displays complete analysis

## Rules and Constraints

### MVP Scope
- Manual distance input (no GPS tracking)
- No integration with Strava, Garmin, or Apple Health
- No social features (no subscriptions, ratings, competitions)
- No separate AI chat
- Manual training data entry
- Deterministic rules for core training decisions
- AI explanations and optional plans do not replace deterministic run analysis

### Technical Constraints
- One platform (Android first, iOS later)
- Minimal dependencies
- No microservices
- No Kubernetes
- No Docker orchestration; production deployment may use the single-container
  image and Render blueprint
- No CI/CD
- Simple architecture

## Future Considerations

### Technical Extensions
- iOS version development
- GPS tracking integration
- Third-party app integrations
- Social features
- AI chat functionality
- Performance prediction
- Weather-based training

### Architecture Benefits
- Clear layer separation for easy platform expansion
- Deterministic and AI components can evolve independently
- Local storage enables offline usage
- Modular design supports new features

## Security

### Basic Security
- HTTPS for all API calls
- JWT-based authentication
- Input validation
- Rate limiting

### Security Considerations
- Protect user training data
- Secure authentication
- Privacy-focused design
- Data integrity

## Database Schema

The database schema supports the main user cycle by storing:
- User profiles and settings
- Training session history
- Analysis results
- Explanation data

## System Design Principles

### Key Design Decisions
- Simplicity over complexity
- Separation of concerns
- Clear data flow
- Minimal dependencies
- User-focused design

### Development Approach
- Iterative development
- Focus on main user cycle
- Minimal viable product
- Continuous improvement