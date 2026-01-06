#!/usr/bin/env sh
set -e

DB_HOST=${DB_HOST:-}
DB_PORT=${DB_PORT:-5432}

if [ -n "$DB_HOST" ]; then
  echo "Esperando a que la base de datos esté lista en ${DB_HOST}:${DB_PORT}..."
  while ! nc -z "$DB_HOST" "$DB_PORT" >/dev/null 2>&1; do
    sleep 1
  done
fi

python manage.py migrate --noinput

if [ "${SKIP_COLLECTSTATIC:-0}" = "0" ]; then
  python manage.py collectstatic --noinput
fi

exec "$@"
