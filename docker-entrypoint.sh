#!/usr/bin/env sh
set -e

# ========= CONFIG =========
DB_HOST="${DB_HOST:-db}"
DB_PORT="${DB_PORT:-3306}"

DB_WAIT_TIMEOUT="${DB_WAIT_TIMEOUT:-180}"
MIGRATION_ATTEMPTS="${MIGRATION_ATTEMPTS:-10}"
MIGRATION_RETRY_DELAY="${MIGRATION_RETRY_DELAY:-6}"

RUN_MAKEMIGRATIONS="${RUN_MAKEMIGRATIONS:-0}"
SKIP_COLLECTSTATIC="${SKIP_COLLECTSTATIC:-0}"

# ========= HELPERS =========
echo "==> Iniciando entrypoint..."

wait_for_dns() {
  echo "==> Esperando DNS para ${DB_HOST}..."
  waited=0
  while ! getent hosts "$DB_HOST" >/dev/null 2>&1; do
    sleep 1
    waited=$((waited + 1))
    if [ "$waited" -ge "$DB_WAIT_TIMEOUT" ]; then
      echo "ERROR: No se pudo resolver el host ${DB_HOST} tras ${DB_WAIT_TIMEOUT}s."
      return 1
    fi
  done
  echo "==> DNS OK: ${DB_HOST}"
}

wait_for_mysql() {
  echo "==> Esperando a que MySQL esté listo en ${DB_HOST}:${DB_PORT}..."

  python - <<'PY'
import os
import time
import pymysql

host = os.environ.get("DB_HOST", "db")
port = int(os.environ.get("DB_PORT", "3306"))

user = os.environ.get("MYSQL_USER") or "root"
password = os.environ.get("MYSQL_PASSWORD") or os.environ.get("MYSQL_ROOT_PASSWORD") or ""
database = os.environ.get("MYSQL_DATABASE") or None

timeout = int(os.environ.get("DB_WAIT_TIMEOUT", "180"))
start = time.time()

while True:
    try:
        conn = pymysql.connect(
            host=host,
            port=port,
            user=user,
            password=password,
            database=database,
            connect_timeout=5,
        )
        conn.close()
        print("==> Conexión a MySQL exitosa.")
        break
    except Exception as exc:
        elapsed = int(time.time() - start)
        print(f"==> MySQL no listo aún ({elapsed}s/{timeout}s): {exc}")
        if elapsed >= timeout:
            raise SystemExit("ERROR: Tiempo de espera agotado esperando MySQL.")
        time.sleep(3)
PY
}

run_migrations() {
  echo "==> Ejecutando migraciones..."

  attempt=1
  while true; do
    if [ "$RUN_MAKEMIGRATIONS" = "1" ]; then
      echo "==> RUN_MAKEMIGRATIONS=1 → ejecutando makemigrations..."
      python manage.py makemigrations --noinput || true
    fi

    if python manage.py migrate --noinput; then
      echo "==> Migraciones completadas correctamente."
      break
    fi

    if [ "$attempt" -ge "$MIGRATION_ATTEMPTS" ]; then
      echo "ERROR: Las migraciones fallaron tras ${attempt} intentos."
      exit 1
    fi

    attempt=$((attempt + 1))
    echo "==> Reintentando migraciones en ${MIGRATION_RETRY_DELAY}s (intento ${attempt}/${MIGRATION_ATTEMPTS})..."
    sleep "$MIGRATION_RETRY_DELAY"
  done
}

run_collectstatic() {
  if [ "$SKIP_COLLECTSTATIC" = "1" ]; then
    echo "==> SKIP_COLLECTSTATIC=1 → saltando collectstatic."
    return 0
  fi

  echo "==> Ejecutando collectstatic..."
  python manage.py collectstatic --noinput
  echo "==> collectstatic completado."
}

# ========= MAIN =========
wait_for_dns
wait_for_mysql
run_migrations
run_collectstatic

echo "==> Iniciando servicio: $*"
exec "$@"
