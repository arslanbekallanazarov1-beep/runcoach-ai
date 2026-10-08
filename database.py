import os
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy import inspect

# На Railway/Render используем /tmp для SQLite, если не задан другой DATABASE_URL
default_db = "sqlite+aiosqlite:////tmp/runcoach.db" if os.environ.get("RENDER") or os.environ.get("RAILWAY_ENVIRONMENT") else "sqlite+aiosqlite:///./runcoach.db"
DATABASE_URL = os.environ.get("DATABASE_URL", default_db)

if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+asyncpg://", 1)
elif DATABASE_URL.startswith("postgresql://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)

engine = create_async_engine(DATABASE_URL, echo=False)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False)

class DeclarativeBase(DeclarativeBase):
    pass

# ... остальной код оставляем прежним ...
