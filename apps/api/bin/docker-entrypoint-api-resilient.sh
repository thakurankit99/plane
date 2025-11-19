#!/bin/bash
set -e

echo "Starting Plane API..."

# Wait for database
python manage.py wait_for_db

# Wait for migrations
python manage.py wait_for_migrations

echo "Starting Gunicorn server..."
exec gunicorn -w "${GUNICORN_WORKERS:-1}" -k uvicorn.workers.UvicornWorker plane.asgi:application --bind 0.0.0.0:"${PORT:-8000}" --max-requests 1200 --max-requests-jitter 1000 --access-logfile - --timeout 120
