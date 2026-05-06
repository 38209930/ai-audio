# OpenResty API Service

Cloud API skeleton for the commercial desktop version.

## Start Locally

Install OpenResty, then run from repository root:

```bash
openresty -p services/openresty-api -c conf/nginx.conf
```

Stop:

```bash
openresty -p services/openresty-api -c conf/nginx.conf -s stop
```

## Implemented Skeleton Routes

- `GET /health`
- `POST /v1/captcha/challenge`
- `POST /v1/captcha/verify`
- `POST /v1/auth/sms/send`
- `POST /v1/auth/sms/login`
- `GET /v1/models/catalog`
- `POST /v1/devices/report`
- `GET /v1/versions/check`

The current handlers are contract-safe stubs. They return deterministic JSON and mark production integrations as pending.

