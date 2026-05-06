# Cloud API Contract

All cloud APIs return JSON:

```json
{
  "ok": true,
  "data": {},
  "error": null,
  "requestId": "req_xxx"
}
```

Error response:

```json
{
  "ok": false,
  "data": null,
  "error": {
    "code": "RATE_LIMITED",
    "message": "Too many requests"
  },
  "requestId": "req_xxx"
}
```

## GET /health

Returns service status and dependency status for MySQL and Redis.

## POST /v1/captcha/challenge

Request:

```json
{
  "phone": "13800138000",
  "deviceId": "device_xxx"
}
```

Response:

```json
{
  "challengeId": "cap_xxx",
  "imageBase64": "data:image/svg+xml;base64,...",
  "prompt": "请按顺序点击：学 习 工 具",
  "expiresIn": 120
}
```

## POST /v1/captcha/verify

Request:

```json
{
  "challengeId": "cap_xxx",
  "clicks": [
    { "x": 123, "y": 88 },
    { "x": 210, "y": 90 },
    { "x": 264, "y": 70 },
    { "x": 318, "y": 92 }
  ]
}
```

Response:

```json
{
  "captchaToken": "ct_xxx",
  "expiresIn": 300
}
```

## POST /v1/auth/sms/send

Request:

```json
{
  "phone": "13800138000",
  "captchaToken": "ct_xxx",
  "deviceId": "device_xxx"
}
```

Response:

```json
{
  "cooldownSeconds": 60,
  "expiresIn": 300,
  "provider": "aliyun",
  "phoneMask": "138****8000"
}
```

When `SMS_DRY_RUN=true`, the response also includes `devCode` for closed testing. Public deployments must set `SMS_DRY_RUN=false`.

## POST /v1/auth/sms/login

Request:

```json
{
  "phone": "13800138000",
  "code": "123456",
  "deviceId": "device_xxx",
  "osName": "Windows",
  "osVersion": "11",
  "appVersion": "0.2.0"
}
```

Response:

```json
{
  "accessToken": "jwt_access",
  "refreshToken": "jwt_refresh",
  "expiresIn": 7200,
  "user": {
    "id": "usr_xxx",
    "phoneMask": "138****8000"
  }
}
```

## GET /v1/models/catalog

Returns available model metadata and direct download links from MySQL, with a static fallback if MySQL is unavailable.

## POST /v1/devices/report

Reports OS, app version, selected acceleration mode, and optional anonymous benchmark.

Request:

```json
{
  "deviceId": "device_xxx",
  "osName": "Windows",
  "osVersion": "11",
  "appVersion": "0.2.0"
}
```

## GET /v1/versions/check?platform=windows&version=0.8.0

Returns latest version, update notes, force-update flag, and download URL.

## Security Behavior

- Captcha answers and captcha tokens are stored in Redis under `ai_audio:captcha:*`.
- Rate-limit counters are stored in Redis under `ai_audio:rate:*`.
- SMS sending requires a one-time `captchaToken`.
- Phone and IP values are persisted as `*_hash` plus masked display fields.
- Logs must not include raw phone numbers, SMS codes, API keys, or raw IPs.

