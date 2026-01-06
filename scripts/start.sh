#!/usr/bin/env sh
set -e

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Se generó un archivo .env a partir de .env.example. Ajusta los valores sensibles antes de continuar."
fi

docker compose up --build
