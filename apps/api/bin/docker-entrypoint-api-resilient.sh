#!/bin/bash
set -e

echo "Starting Plane API..."

# Wait for database
python manage.py wait_for_db

# Wait for migrations
python manage.py wait_for_migrations

# Initialize instance if not exists
echo "Checking instance configuration..."
python manage.py register_instance "plane-koyeb" 2>/dev/null || echo "Instance registration skipped"
python manage.py configure_instance 2>/dev/null || echo "Instance configuration skipped"

# Ensure instance is marked as setup done
python -c "
from plane.license.models import Instance
instance = Instance.objects.first()
if instance and not instance.is_setup_done:
    instance.is_setup_done = True
    instance.save()
    print('Instance setup marked as complete')
" 2>/dev/null || echo "Instance check skipped"

echo "Starting Gunicorn server..."
exec gunicorn -w "${GUNICORN_WORKERS:-1}" -k uvicorn.workers.UvicornWorker plane.asgi:application --bind 0.0.0.0:"${PORT:-8000}" --max-requests 1200 --max-requests-jitter 1000 --access-logfile - --timeout 120
