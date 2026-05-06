local req = require "lib.request"
local privacy = require "lib.privacy"
local limiter = require "middleware.rate_limit"
local res = require "lib.json_response"

local body, err = req.json_body()
if not body then
  return res.err(400, "INVALID_JSON", err)
end

if not body.captchaToken then
  return res.err(403, "CAPTCHA_REQUIRED", "Captcha token is required before sending SMS")
end

local phone = body.phone or ""
local ip = req.client_ip()
local phone_hash = privacy.pseudo_hash(phone)
local ip_hash = privacy.pseudo_hash(ip)

local ok_phone = limiter.hit("sms:phone:" .. phone_hash, 1, 60)
if not ok_phone then
  return res.err(429, "PHONE_COOLDOWN", "Please wait before requesting another code")
end

local ok_ip = limiter.hit("sms:ip:" .. ip_hash, 20, 3600)
if not ok_ip then
  return res.err(429, "IP_RATE_LIMITED", "Too many SMS requests from this network")
end

-- Placeholder: production integration sends SMS through Aliyun provider.
res.ok({
  cooldownSeconds = 60,
  provider = "aliyun",
  phoneMask = privacy.mask_phone(phone),
})

