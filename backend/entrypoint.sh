#!/bin/bash
set -e

export DJANGO_SETTINGS_MODULE="${DJANGO_SETTINGS_MODULE:-config.settings.production}"

# Create extensions and run migrations only for the web/init role
if [ "${RUN_MIGRATIONS:-false}" = "true" ]; then
    echo "==> Creating database extensions..."
    python manage.py shell -c "
from django.db import connection
with connection.cursor() as c:
    c.execute(\"CREATE EXTENSION IF NOT EXISTS postgis;\")
    c.execute(\"CREATE EXTENSION IF NOT EXISTS postgis_topology;\")
    c.execute(\"CREATE EXTENSION IF NOT EXISTS vector;\")
print('Extensions created.')
" || echo "Extension creation failed (may already exist or permissions issue), continuing..."

    echo "==> Running migrations..."
    python manage.py migrate --no-input

    echo "==> Collecting static files..."
    python manage.py collectstatic --no-input --clear
fi

exec "$@"
