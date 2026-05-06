# OpenResty API Service

Cloud API service for the commercial desktop version.

## Start Locally

Install OpenResty, then run from repository root:

```bash
openresty -p services/openresty-api -c conf/nginx.conf
```

Stop:

```bash
openresty -p services/openresty-api -c conf/nginx.conf -s stop
```

## Implemented Routes

- `GET /health`
- `POST /v1/captcha/challenge`
- `POST /v1/captcha/verify`
- `POST /v1/auth/sms/send`
- `POST /v1/auth/sms/login`
- `POST /v1/auth/refresh`
- `GET /v1/models/catalog`
- `POST /v1/devices/report`
- `GET /v1/versions/check`

The handlers use Redis for captcha/rate-limit state and MySQL for user, SMS, device, model catalog, and version data. SMS defaults to dry-run mode for closed testing and can be switched to Aliyun SMS with environment variables.

## Docker

Local API dependencies are declared in the service `Dockerfile`:

- `lua-resty-redis`
- `lua-resty-mysql`
- `lua-resty-http`
- `lua-resty-openssl`

Run the full local stack from the repository root:

```bash
docker compose -f docker-compose.dev.yml up -d --build
```

Smoke test:

```bash
bash deploy/aliyun/smoke-test.sh http://127.0.0.1:8080
```

## Required Environment

Copy `deploy/aliyun/env.example` to `deploy/aliyun/.env` for ECS deployment. Do not commit `.env`.

Important values:

- `MYSQL_*`: RDS or self-hosted MySQL connection.
- `REDIS_*`: Redis connection.
- `HMAC_SECRET`: HMAC secret for phone/IP/code hashes.
- `JWT_SECRET`: signing secret for auth tokens.
- `SMS_DRY_RUN`: set `true` for closed testing, `false` for real Aliyun SMS.
- `ALIYUN_SMS_*`: Aliyun SMS credentials, sign name, and template code.

## Privacy Notes

Handlers store `phone_hash`/`phone_mask` and `ip_hash`/`ip_mask`. Logs must not include raw phone numbers, SMS codes, API keys, or raw IPs.
