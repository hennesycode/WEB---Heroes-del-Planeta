# syntax=docker/dockerfile:1
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Dependencias del sistema: netcat (esperas), mysql-client (debug), build essentials (si hay wheels)
RUN apt-get update && apt-get install -y --no-install-recommends \
    netcat-openbsd \
    default-mysql-client \
    gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt

COPY . .

RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 5020

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:5020", "--workers", "3"]
