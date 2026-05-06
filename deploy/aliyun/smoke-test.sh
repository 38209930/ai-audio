#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://127.0.0.1:8080}"

echo "== health =="
curl -fsS "${BASE_URL}/health"
echo

echo "== models =="
curl -fsS "${BASE_URL}/v1/models/catalog"
echo

echo "== versions =="
curl -fsS "${BASE_URL}/v1/versions/check?platform=windows&version=0.1.0"
echo

echo "== guest login =="
curl -fsS \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"smoke-device","osName":"Linux","osVersion":"ECS","appVersion":"0.2.0"}' \
  "${BASE_URL}/v1/auth/guest/login"
echo

echo "== captcha challenge =="
curl -fsS \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000"}' \
  "${BASE_URL}/v1/captcha/challenge"
echo
