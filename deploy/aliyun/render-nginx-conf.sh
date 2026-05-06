#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/home/ai-audio/api}"
ENV_FILE="${APP_DIR}/deploy/aliyun/.env"
TEMPLATE="${APP_DIR}/deploy/aliyun/nginx-https.example.conf"
TARGET="${NGINX_TARGET:-/etc/nginx/conf.d/ai-audio-api.conf}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}." >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

if [[ -z "${API_DOMAIN:-}" ]]; then
  echo "API_DOMAIN is required in ${ENV_FILE}." >&2
  exit 1
fi

sudo mkdir -p "$(dirname "${TARGET}")"
sed "s|\${API_DOMAIN}|${API_DOMAIN}|g" "${TEMPLATE}" | sudo tee "${TARGET}" >/dev/null
sudo nginx -t
sudo systemctl reload nginx
echo "Nginx config rendered to ${TARGET} for ${API_DOMAIN}."
