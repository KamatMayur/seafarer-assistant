# One image for the API, the worker and migrations. Build from the repo root:
#   docker build -f infra/Dockerfile -t seafarer-assistant .
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1

# Tesseract for scanned circulars (English + Hindi). Optional at runtime: without it, scans go to review.
RUN apt-get update \
 && apt-get install -y --no-install-recommends tesseract-ocr tesseract-ocr-eng tesseract-ocr-hin \
 && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 10001 app
WORKDIR /app

COPY backend/pyproject.toml backend/pyproject.toml
COPY scraper/pyproject.toml scraper/pyproject.toml
COPY backend/sa_backend backend/sa_backend
COPY scraper/sa_scraper scraper/sa_scraper
COPY scraper/sources scraper/sources
RUN pip install -e ./backend -e "./scraper[ocr]"  # editable: sources/ and migrations resolve from /app

COPY backend/alembic.ini backend/alembic.ini
COPY backend/migrations backend/migrations

ENV SA_DATA_DIR=/data
RUN mkdir -p /data && chown app:app /data
USER app
EXPOSE 8000
CMD ["uvicorn", "sa_backend.api.app:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips=*"]
