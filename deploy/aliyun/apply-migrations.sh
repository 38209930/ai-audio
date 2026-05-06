#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ROOT_DIR}/deploy/aliyun/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Copy env.example to .env first." >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

mysql \
  --host="${MYSQL_HOST}" \
  --port="${MYSQL_PORT:-3306}" \
  --user="${MYSQL_USER}" \
  --password="${MYSQL_PASSWORD}" \
  --database="${MYSQL_DATABASE}" \
  --default-character-set=utf8mb4 \
  < "${ROOT_DIR}/db/migrations/001_base_schema.sql"

mysql \
  --host="${MYSQL_HOST}" \
  --port="${MYSQL_PORT:-3306}" \
  --user="${MYSQL_USER}" \
  --password="${MYSQL_PASSWORD}" \
  --database="${MYSQL_DATABASE}" \
  --default-character-set=utf8mb4 \
  < "${ROOT_DIR}/db/migrations/002_seed_model_catalog.sql"

mysql \
  --host="${MYSQL_HOST}" \
  --port="${MYSQL_PORT:-3306}" \
  --user="${MYSQL_USER}" \
  --password="${MYSQL_PASSWORD}" \
  --database="${MYSQL_DATABASE}" \
  --default-character-set=utf8mb4 \
  < "${ROOT_DIR}/db/migrations/003_seed_app_versions.sql"

mysql \
  --host="${MYSQL_HOST}" \
  --port="${MYSQL_PORT:-3306}" \
  --user="${MYSQL_USER}" \
  --password="${MYSQL_PASSWORD}" \
  --database="${MYSQL_DATABASE}" \
  --default-character-set=utf8mb4 \
  < "${ROOT_DIR}/db/migrations/004_guest_trials.sql"

echo "Migrations applied to ${MYSQL_DATABASE}."
