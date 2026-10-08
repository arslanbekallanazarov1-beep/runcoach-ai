from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    first_name: Mapped[str | None] = mapped_column(String(50), nullable=True)
    last_name: Mapped[str | None] = mapped_column(String(50), nullable=True)
    goal: Mapped[str | None] = mapped_column(String(80), nullable=True)
    experience_level: Mapped[str | None] = mapped_column(String(40), nullable=True)
    weekly_mileage_km: Mapped[float | None] = mapped_column(Float, nullable=True)
    max_hr: Mapped[int | None] = mapped_column(Integer, nullable=True)
    age: Mapped[int | None] = mapped_column(Integer, nullable=True)
    available_training_days: Mapped[str | None] = mapped_column(String(80), nullable=True)
    is_active: Mapped[bool] = mapped_column(default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    runs: Mapped[list["Run"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    recommendations: Mapped[list["Recommendation"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
    )


class Run(Base):
    __tablename__ = "runs"
    __table_args__ = (
        CheckConstraint("distance_km > 0", name="check_run_distance_positive"),
        CheckConstraint("time_seconds > 0", name="check_run_time_positive"),
        CheckConstraint("avg_hr > 0", name="check_run_avg_hr_positive"),
        CheckConstraint("rpe BETWEEN 1 AND 10", name="check_run_rpe_range"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    distance_km: Mapped[float] = mapped_column(Float, nullable=False)
    time_seconds: Mapped[int] = mapped_column(Integer, nullable=False)
    pace_formatted: Mapped[str | None] = mapped_column(String(10), nullable=True)
    avg_hr: Mapped[int] = mapped_column(Integer, nullable=False)
    rpe: Mapped[int] = mapped_column(Integer, nullable=False)
    sleep_hours: Mapped[float | None] = mapped_column(Float, nullable=True)
    resting_hr: Mapped[int | None] = mapped_column(Integer, nullable=True)
    date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    user: Mapped[User] = relationship(back_populates="runs")
    analysis: Mapped["RunAnalysis | None"] = relationship(
        back_populates="run",
        cascade="all, delete-orphan",
        uselist=False,
    )
    recommendations: Mapped[list["Recommendation"]] = relationship(back_populates="based_on_run")


class RunAnalysis(Base):
    __tablename__ = "run_analyses"
    __table_args__ = (
        CheckConstraint("training_load >= 0", name="check_analysis_training_load_nonnegative"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    run_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("runs.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    training_load: Mapped[float] = mapped_column(Float, nullable=False)
    intensity_zone: Mapped[str] = mapped_column(String(50), nullable=False)
    base_recommendation: Mapped[str | None] = mapped_column(String(100), nullable=True)
    ai_explanation: Mapped[str] = mapped_column(Text, nullable=False)

    run: Mapped[Run] = relationship(back_populates="analysis")


class Recommendation(Base):
    __tablename__ = "recommendations"
    __table_args__ = (
        CheckConstraint("target_distance_km > 0", name="check_recommendation_distance_positive"),
        CheckConstraint("target_rpe BETWEEN 1 AND 10", name="check_recommendation_rpe_range"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    based_on_run_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("runs.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    target_distance_km: Mapped[float] = mapped_column(Float, nullable=False)
    target_pace_range: Mapped[str] = mapped_column(String(100), nullable=False)
    target_rpe: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    user: Mapped[User] = relationship(back_populates="recommendations")
    based_on_run: Mapped[Run] = relationship(back_populates="recommendations")
