#!/bin/bash
set -e

echo "Starting Plane API..."

# Wait for database
python manage.py wait_for_db

# Wait for migrations
python manage.py wait_for_migrations

# Collect system information for machine signature
HOSTNAME=$(hostname)
MAC_ADDRESS=$(ip link show | awk '/ether/ {print $2}' | head -n 1 || echo "unknown")
CPU_INFO=$(cat /proc/cpuinfo 2>/dev/null || echo "unknown")
MEMORY_INFO=$(free -h 2>/dev/null || echo "unknown")
DISK_INFO=$(df -h 2>/dev/null || echo "unknown")

# Concatenate information and compute SHA-256 hash
SIGNATURE=$(echo "$HOSTNAME$MAC_ADDRESS$CPU_INFO$MEMORY_INFO$DISK_INFO" | sha256sum | awk '{print $1}')

# Export the variables
export MACHINE_SIGNATURE=$SIGNATURE

# Register instance (run in background to not block startup)
echo "Registering instance in background..."
(python manage.py register_instance "$MACHINE_SIGNATURE" 2>&1 | head -20 || echo "Warning: Instance registration failed") &

# Load the configuration variable
echo "Configuring instance..."
timeout 10 python manage.py configure_instance || echo "Warning: Instance configuration failed, continuing anyway..."

# Create the default bucket
echo "Creating default bucket..."
timeout 10 python manage.py create_bucket || echo "Warning: Bucket creation failed, continuing anyway..."

# Clear Cache before starting to remove stale values
echo "Clearing cache..."
timeout 5 python manage.py clear_cache || echo "Warning: Cache clear failed, continuing anyway..."

echo "Starting Gunicorn server..."
exec gunicorn -w "${GUNICORN_WORKERS:-1}" -k uvicorn.workers.UvicornWorker plane.asgi:application --bind 0.0.0.0:"${PORT:-8000}" --max-requests 1200 --max-requests-jitter 1000 --access-logfile - --timeout 120
