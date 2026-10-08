# Database Schema - MVP Database Schema

## Overview
The backend uses async SQLite by default for local development
(`sqlite+aiosqlite:///./runcoach.db`), requiring no separate database service.
PostgreSQL is also supported by setting `DATABASE_URL`; the connection details
below describe that optional deployment setup.

## Database Connection

### Connection String
```
host=localhost
port=5432
dbname=runcoach_ai
user=runcoach_ai
password=<secure_password>
sslmode=disable
```

## Database Schema

### 1. users
User accounts table

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    max_hr INTEGER,
    age INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

**Table Purpose**: Store user account information and authentication data.

The current SQLAlchemy model also stores runner profile fields on `users`,
including `goal`, `experience_level`, `weekly_mileage_km`, `max_hr`, `age`, and
`available_training_days`. Password hashes use PBKDF2; plaintext passwords
and JWTs are never stored in this table. Some fields are nullable to keep
older local development rows readable.

### 2. runner_profiles
Runner profiles and training settings

```sql
CREATE TABLE runner_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    goal VARCHAR(20) NOT NULL,
    weekly_workouts INTEGER DEFAULT 3,
    age INTEGER,
    gender VARCHAR(10),
    current_level INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT check_goal CHECK (goal IN ('5K', '10K', 'HALF_MARATHON', 'GENERAL_FITNESS')),
    CONSTRAINT check_weekly_workouts CHECK (weekly_workouts BETWEEN 1 AND 7)
);
```

**Table Purpose**: Store runner's training goals, experience level, and weekly targets that influence deterministic training analysis.

### 3. workouts
Training session records

The current SQLAlchemy implementation uses `runs` and its one-to-one
`run_analyses` table: raw run inputs, calculated pace, and timestamp are stored
in `runs`; training load, intensity zone, base recommendation, and AI feedback
are stored in `run_analyses`.
The `runs` table also contains optional `sleep_hours` (0 through 24) and
`resting_hr` fields
for recovery-aware deterministic recommendations and coach explanations.
Startup applies additive columns to older local SQLite databases. Use schema
migrations for production database evolution.

```sql
CREATE TABLE workouts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date TIMESTAMP WITH TIME ZONE NOT NULL,
    distance DECIMAL(5,2) NOT NULL,
    duration INTEGER NOT NULL,
    pace DECIMAL(6,2),
    avg_heart_rate INTEGER,
    max_heart_rate INTEGER,
    rpe INTEGER,
    sleep_duration DECIMAL(4,1),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT check_distance CHECK (distance > 0 AND distance <= 500),
    CONSTRAINT check_duration CHECK (duration > 0 AND duration <= 1440),
    CONSTRAINT check_rpe CHECK (rpe IS NULL OR (rpe >= 1 AND rpe <= 10)),
    CONSTRAINT check_sleep_duration CHECK (sleep_duration IS NULL OR (sleep_duration > 0 AND sleep_duration <= 24))
);
```

**Table Purpose**: Store detailed training session data for deterministic analysis and user history.

## Indexes

### Performance Indexes
```sql
-- User authentication and lookup
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_is_active ON users(is_active);

-- Profile lookup and filtering
CREATE INDEX idx_runner_profiles_user_id ON runner_profiles(user_id);
CREATE INDEX idx_runner_profiles_goal ON runner_profiles(goal);

-- Training history and analysis
CREATE INDEX idx_workouts_user_id ON workouts(user_id);
CREATE INDEX idx_workouts_date ON workouts(date);
CREATE INDEX idx_workouts_user_date ON workouts(user_id, date);
```

## Views

### 1. vw_user_workout_summary
Combined view of user workouts with analysis results

```sql
CREATE VIEW vw_user_workout_summary AS
SELECT
    w.user_id,
    w.date,
    w.distance,
    w.duration,
    w.pace,
    w.avg_heart_rate,
    w.max_heart_rate,
    w.rpe,
    w.sleep_duration,
    wa.intensity AS workout_intensity
FROM workouts w
LEFT JOIN workout_analyses wa ON w.id = wa.workout_id
WHERE w.is_active = TRUE;
```

**View Purpose**: Provides consolidated data for user history and progress tracking.

## Functions

### 1. calculate_pace(distance_km, duration_minutes)
Calculate running pace

```sql
CREATE OR REPLACE FUNCTION calculate_pace(distance_km DECIMAL, duration_minutes INTEGER)
RETURNS DECIMAL AS $$
BEGIN
    IF distance_km <= 0 OR duration_minutes <= 0 THEN
        RETURN NULL;
    END IF;
    RETURN duration_minutes / distance_km;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

## Security

### Basic Security
- HTTPS for database connections
- Connection encryption
- Role-based access control
- Regular backups

### Security Considerations
- Protect user training data
- Secure authentication storage
- Backup and recovery procedures
- Data integrity constraints

## Schema Design Principles

### Design Decisions
- Normalized schema for data integrity
- Indexes for common queries
- Constraints for data validation
- Views for common reporting needs

### Architecture Benefits
- Simple, maintainable structure
- Easy to understand and modify
- Supports main user cycle requirements
- Foundation for future enhancements