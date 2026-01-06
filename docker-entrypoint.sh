#!/usr/bin/env sh
set -e

DB_HOST=${DB_HOST:-}
DB_PORT=${DB_PORT:-3306}
DB_WAIT_TIMEOUT=${DB_WAIT_TIMEOUT:-120}
MIGRATION_ATTEMPTS=${MIGRATION_ATTEMPTS:-5}
MIGRATION_RETRY_DELAY=${MIGRATION_RETRY_DELAY:-5}

if [ -z "$DB_HOST" ] && [ -n "$DATABASE_URL" ]; then
  DB_HOST=$(python - <<'PY'
import os
from urllib.parse import urlparse

url = urlparse(os.environ["DATABASE_URL"])
print(url.hostname or "")
PY
  )
  DB_PORT=${DB_PORT:-$(python - <<'PY'
import os
from urllib.parse import urlparse

url = urlparse(os.environ["DATABASE_URL"])
print(url.port or 3306)
PY
  )}
fi

wait_for_dns() {
  waited=0
  while ! getent hosts "$1" >/dev/null 2>&1; do
    sleep 1
    waited=$((waited + 1))
    if [ "$waited" -ge "$DB_WAIT_TIMEOUT" ]; then
      echo "No se pudo resolver el host $1 tras ${DB_WAIT_TIMEOUT}s."
      return 1
    fi
  done
  return 0
}

if [ -n "$DB_HOST" ]; then
  echo "Esperando a que el DNS resuelva ${DB_HOST}..."
  wait_for_dns "$DB_HOST" || exit 1

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

python <<'PY'
import os
import time
import pymysql

host = os.environ.get("DB_HOST", "") or "localhost"
port = int(os.environ.get("DB_PORT", "3306"))
user = os.environ.get("MYSQL_USER") or os.environ.get("DB_USER") or "root"
password = os.environ.get("MYSQL_PASSWORD") or os.environ.get("DB_PASSWORD") or os.environ.get("MYSQL_ROOT_PASSWORD", "")
database = os.environ.get("MYSQL_DATABASE") or os.environ.get("DB_NAME") or None
attempts = int(os.environ.get("MIGRATION_ATTEMPTS", "5"))
delay = int(os.environ.get("MIGRATION_RETRY_DELAY", "5"))

for attempt in range(1, attempts + 1):
    try:
        pymysql.connect(host=host, port=port, user=user, password=password, database=database, connect_timeout=5)
        print("Conexión preliminar a MySQL exitosa.")
        break
    except Exception as exc:  # noqa: BLE001
        print(f"(Intento {attempt}/{attempts}) Conexión preliminar falló: {exc}")
        if attempt == attempts:
            raise
        time.sleep(delay)
PY

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
