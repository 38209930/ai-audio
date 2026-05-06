# Aliyun ECS Deployment

This runbook deploys the OpenResty/Lua API for the commercial Windows client.

## 1. ECS

Install base packages on Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y git docker.io docker-compose-plugin mysql-client redis-tools nginx certbot python3-certbot-nginx
sudo systemctl enable --now docker nginx
```

Deploy the repository to:

```bash
sudo mkdir -p /home/ai-audio/api
sudo chown -R "$USER":"$USER" /home/ai-audio
git clone https://github.com/38209930/ai-audio.git /home/ai-audio/api
cd /home/ai-audio/api
```

Security group:

- Open `80/tcp` and `443/tcp` to the public internet.
- Keep `22/tcp` restricted to your own IP.
- Do not expose MySQL or Redis publicly.

## 2. MySQL

Create database and least-privilege API user:

```sql
CREATE DATABASE ai_audio CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'ai_audio_api'@'%' IDENTIFIED BY 'replace-with-strong-password';
GRANT SELECT, INSERT, UPDATE, DELETE ON ai_audio.* TO 'ai_audio_api'@'%';
FLUSH PRIVILEGES;
```

Prefer Aliyun private network access from ECS to RDS. Then run:

```bash
cp deploy/aliyun/env.example deploy/aliyun/.env
vim deploy/aliyun/.env
bash deploy/aliyun/apply-migrations.sh
```

## 3. Redis

Use Redis for short-lived captcha answers, captcha tokens, rate limits, SMS counters, and future token blacklist keys. All API keys use the `ai_audio:*` prefix.

Validate connectivity:

```bash
redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" ping
```

## 4. API Service

Start OpenResty:

```bash
cd /home/ai-audio/api
bash deploy/aliyun/restart-api.sh
```

Local health check on ECS:

```bash
bash deploy/aliyun/smoke-test.sh http://127.0.0.1:8080
```

## 5. HTTPS

Set `API_DOMAIN` in `deploy/aliyun/.env`. The deployed Nginx config uses:

```text
ssl_certificate /home/ssl/ccun.net.pem;
ssl_certificate_key /home/ssl/ccun.net.key;
```

Render and reload Nginx:

```bash
cd /home/ai-audio/api
bash deploy/aliyun/render-nginx-conf.sh
```

## 6. SMS

SMS login is optional until Aliyun SMS credentials are ready. Without credentials, `/v1/auth/sms/send` returns `SMS_NOT_CONFIGURED`.

For closed local testing only, set:

```text
SMS_DRY_RUN=true
```

This returns `devCode` in `/v1/auth/sms/send`. Do not use dry-run for public testing. Before enabling phone login:

```text
SMS_DRY_RUN=false
ALIYUN_SMS_ACCESS_KEY_ID=...
ALIYUN_SMS_ACCESS_KEY_SECRET=...
ALIYUN_SMS_SIGN_NAME=...
ALIYUN_SMS_TEMPLATE_CODE=...
```

The SMS template must expose a `code` variable, for example: `Your verification code is ${code}`.

## 7. Acceptance Checks

- `https://api.example.com/health` returns `status=ok`.
- MySQL migrations `001` to `004` are applied.
- Redis receives `ai_audio:captcha:*` and `ai_audio:rate:*` keys with TTL.
- Guest login returns a 30-day trial token for a new device ID.
- Captcha challenge returns a base64 SVG image and expires in 120 seconds.
- SMS cannot be sent without a valid captcha token.
- Login writes masked phone/IP fields to MySQL; logs do not contain raw phone, SMS code, API key, or raw IP.
