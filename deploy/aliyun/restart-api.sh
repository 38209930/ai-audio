#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/home/ai-audio/api}"
cd "${APP_DIR}/deploy/aliyun"

if [[ ! -f ".env" ]]; then
  echo "Missing ${APP_DIR}/deploy/aliyun/.env." >&2
  exit 1
fi

docker compose -f docker-compose.aliyun.yml --env-file .env up -d --build

if [[ -f "${APP_DIR}/deploy/aliyun/render-nginx-conf.sh" ]]; then
  bash "${APP_DIR}/deploy/aliyun/render-nginx-conf.sh"
fi

bash "${APP_DIR}/deploy/aliyun/smoke-test.sh" "http://127.0.0.1:8080"
