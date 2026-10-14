# BasementIO template: Python backend (FastAPI, Django, Flask, AI/agent services)
# Expects requirements.txt. Set CMD for your framework at the bottom.

FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PORT=8000

WORKDIR /app

# Dependencies first so code changes don't reinstall them
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
RUN useradd --create-home --uid 10001 app && chown -R app /app
USER app

EXPOSE 8000
# 'exec' makes the server PID 1 so it gets SIGTERM on redeploys. Pick one:
CMD ["sh", "-c", "exec uvicorn main:app --host 0.0.0.0 --port ${PORT}"]
# Django: CMD ["sh", "-c", "exec gunicorn myproject.wsgi --bind 0.0.0.0:${PORT} --workers 4"]
# Flask:  CMD ["sh", "-c", "exec gunicorn app:app --bind 0.0.0.0:${PORT} --workers 4"]
