# Cloud API Smoke Tests

Run basic checks against a local or ECS API endpoint:

```bash
bash deploy/aliyun/smoke-test.sh http://127.0.0.1:8080
bash deploy/aliyun/smoke-test.sh https://api.example.com
```

Captcha verification cannot be fully automated without reading the returned image and submitting coordinates. For manual testing:

1. Call `/v1/captcha/challenge`.
2. Display `imageBase64` in a browser.
3. Submit ordered click coordinates to `/v1/captcha/verify`.
4. Use the returned `captchaToken` in `/v1/auth/sms/send`.
5. With `SMS_DRY_RUN=true`, use `devCode` from the send response to call `/v1/auth/sms/login`.
