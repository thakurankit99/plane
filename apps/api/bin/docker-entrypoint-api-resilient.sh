#!/bin/bash
set -e

echo "Starting Plane API..."

# Wait for database
python manage.py wait_for_db

# Wait for migrations
python manage.py wait_for_migrations

# Initialize instance - proper error handling
echo "Initializing Plane instance..."
python manage.py shell <<'PYEOF'
import sys
import secrets
from django.utils import timezone
from plane.license.models import Instance
from plane.db.models import User

try:
    instance = Instance.objects.first()
    
    if not instance:
        print("Creating new Plane instance...")
        instance = Instance.objects.create(
            instance_name="Plane Instance",
            instance_id=secrets.token_hex(12),
            current_version="v0.23.0",
            latest_version="v0.23.0",
            last_checked_at=timezone.now(),
            is_setup_done=True,  # Set to True to allow frontend access
            is_telemetry_enabled=False,
            is_support_required=False,
        )
        print(f"✓ Instance created: {instance.instance_name} (ID: {instance.instance_id})")
        print("✓ Instance ready - you can now create admin account")
    else:
        print(f"✓ Instance found: {instance.instance_name} (ID: {instance.instance_id})")
        # Check if there are any users
        user_count = User.objects.count()
        print(f"  Users in database: {user_count}")
        
        # Always ensure is_setup_done is True to allow access
        if not instance.is_setup_done:
            instance.is_setup_done = True
            instance.save()
            print("✓ Instance marked as setup complete")
        else:
            print("✓ Instance already configured")
            
except Exception as e:
    print(f"✗ Error initializing instance: {e}")
    sys.exit(1)
PYEOF

if [ $? -ne 0 ]; then
    echo "Failed to initialize instance. Exiting..."
    exit 1
fi

# Configure instance settings
echo "Configuring instance settings..."
python manage.py configure_instance || echo "Warning: Instance configuration may already exist"

echo "Instance initialization complete!"
echo "Starting Gunicorn server..."
exec gunicorn -w "${GUNICORN_WORKERS:-1}" -k uvicorn.workers.UvicornWorker plane.asgi:application --bind 0.0.0.0:"${PORT:-8000}" --max-requests 1200 --max-requests-jitter 1000 --access-logfile - --timeout 120
