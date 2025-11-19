#!/bin/bash
# Script to initialize Plane instance in the database

echo "Setting up Plane instance..."

# Register the instance
python manage.py register_instance "plane-koyeb-instance"

# Configure instance variables
python manage.py configure_instance

# Mark instance as setup done and activated
python manage.py shell << 'EOF'
from plane.license.models import Instance
instance = Instance.objects.first()
if instance:
    instance.is_setup_done = True
    instance.is_activated = True
    instance.save()
    print(f"Instance configured: {instance.instance_name}")
    print(f"  - is_setup_done: {instance.is_setup_done}")
    print(f"  - is_activated: {instance.is_activated}")
else:
    print("ERROR: No instance found!")
EOF

echo "Instance setup complete!"
