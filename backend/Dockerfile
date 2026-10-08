FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt \
    && groupadd --system app \
    && useradd --system --gid app --home-dir /app app \
    && mkdir -p /var/data \
    && chown app:app /var/data

COPY --chown=app:app src ./src

USER app

EXPOSE 8000

CMD ["sh", "-c", "exec uvicorn runcoach_ai.main:app --app-dir src --host 0.0.0.0 --port ${PORT:-8000}"]
