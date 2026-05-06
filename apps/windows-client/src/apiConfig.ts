export const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL ?? "http://127.0.0.1:8080";

export const API_ENDPOINTS = {
  health: "/health",
  captchaChallenge: "/v1/captcha/challenge",
  captchaVerify: "/v1/captcha/verify",
  smsSend: "/v1/auth/sms/send",
  smsLogin: "/v1/auth/sms/login",
  guestLogin: "/v1/auth/guest/login",
  session: "/v1/auth/session",
  modelsCatalog: "/v1/models/catalog",
  versionsCheck: "/v1/versions/check",
  devicesReport: "/v1/devices/report",
} as const;
