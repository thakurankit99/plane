#!/bin/bash
set -e

echo "Starting Plane API..."

# Wait for database
python manage.py wait_for_db

# Wait for migrations
python manage.py wait_for_migrations

# Initialize instance if not exists
echo "Checking instance configuration..."
python manage.py shell << 'PYEOF'
from plane.license.models import Instance
import secrets
from django.utils import timezone

instance = Instance.objects.first()
if not instance:
    print("No instance found. Creating new instance...")
    instance = Instance.objects.create(
        instance_name="Plane Instance",
        instance_id=secrets.token_hex(12),
        current_version="v0.23.0",
        latest_version="v0.23.0",
        last_checked_at=timezone.now(),
        is_setup_done=True,
        is_telemetry_enabled=False,
        is_support_required=False,
    )
    print(f"Instance created: {instance.instance_name}")
elif not instance.is_setup_done:
    print("Marking instance setup as complete...")
    instance.is_setup_done = True
    instance.save()
    print(f"Instance setup completed: {instance.instance_name}")
else:
    print(f"Instance already configured: {instance.instance_name}")
PYEOF

# Configure instance variables
echo "Configuring instance variables..."
python manage.py configure_instance || echo "Instance configuration already exists"

echo "Starting Gunicorn server..."
exec gunicorn -w "${GUNICORN_WORKERS:-1}" -k uvicorn.workers.UvicornWorker plane.asgi:application --bind 0.0.0.0:"${PORT:-8000}" --max-requests 1200 --max-requests-jitter 1000 --access-logfile - --timeout 120
