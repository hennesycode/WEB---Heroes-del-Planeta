#!/usr/bin/env sh
set -e

DB_HOST=${DB_HOST:-}
DB_PORT=${DB_PORT:-3306}
DB_WAIT_TIMEOUT=${DB_WAIT_TIMEOUT:-120}
MIGRATION_ATTEMPTS=${MIGRATION_ATTEMPTS:-5}
MIGRATION_RETRY_DELAY=${MIGRATION_RETRY_DELAY:-5}

if [ -n "$DB_HOST" ]; then
  echo "Esperando a que la base de datos esté lista en ${DB_HOST}:${DB_PORT}..."
  waited=0
  while ! nc -z "$DB_HOST" "$DB_PORT" >/dev/null 2>&1; do
    sleep 1
    waited=$((waited + 1))
    if [ "$waited" -ge "$DB_WAIT_TIMEOUT" ]; then
      echo "Tiempo de espera agotado tras ${DB_WAIT_TIMEOUT}s para ${DB_HOST}:${DB_PORT}."
      exit 1
    fi
  done
fi

attempt=1
while true; do
  if python manage.py migrate --noinput; then
    break
  fi

  if [ "$attempt" -ge "$MIGRATION_ATTEMPTS" ]; then
    echo "Las migraciones fallaron tras ${attempt} intentos."
    exit 1
  fi

  attempt=$((attempt + 1))
  echo "Reintentando migraciones en ${MIGRATION_RETRY_DELAY}s (intento ${attempt}/${MIGRATION_ATTEMPTS})..."
  sleep "$MIGRATION_RETRY_DELAY"
done

if [ "${SKIP_COLLECTSTATIC:-0}" = "0" ]; then
  python manage.py collectstatic --noinput
fi

exec "$@"
