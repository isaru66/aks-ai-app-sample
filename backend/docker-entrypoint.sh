#!/bin/bash
set -e

echo "Starting backend container"
echo "Connecting to PostgreSQL at ${POSTGRESQL_HOST}:${POSTGRESQL_PORT}"
echo "Using database: ${POSTGRESQL_DATABASE}, user: ${POSTGRESQL_USER}"
echo "Waiting for PostgreSQL to be ready..."
# Wait for PostgreSQL
while ! nc -z ${POSTGRESQL_HOST:-localhost} ${POSTGRESQL_PORT:-5432}; do
  sleep 0.5
done
echo "PostgreSQL is ready!"

# Only run migrations if AUTO_MIGRATE is enabled (for local dev)
# In Kubernetes, migrations are handled by a separate Job
if [ "${AUTO_MIGRATE:-true}" = "true" ]; then
  echo "Running database migrations..."
  alembic upgrade head
else
  echo "Skipping auto-migration (handled by Helm job or manual process)"
fi

echo "Starting application..."
exec "$@"
