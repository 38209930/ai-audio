local mysql = require "lib.mysql_client"
local req = require "lib.request"
local privacy = require "lib.privacy"
local crypto = require "lib.crypto"
local captcha = require "lib.captcha"
local limiter = require "middleware.rate_limit"
local sms = require "providers.aliyun_sms"
local config = require "lib.config"
local res = require "lib.json_response"

local body, err = req.json_body()
if not body then
  return res.err(400, "INVALID_JSON", err)
end

if not body.phone or body.phone == "" then
  return res.err(400, "MISSING_PHONE", "phone is required")
end
if not sms.is_configured() then
  return res.err(503, "SMS_NOT_CONFIGURED", "SMS login is not configured yet")
end
if not body.captchaToken then
  return res.err(403, "CAPTCHA_REQUIRED", "Captcha token is required before sending SMS")
end

local phone = body.phone
local ip = req.client_ip()
local device_id = body.deviceId or "unknown"
local phone_hash = privacy.phone_hash(phone)
local ip_hash = privacy.ip_hash(ip)

local token_record, token_err = captcha.consume_token(body.captchaToken)
if not token_record then
  return res.err(403, token_err or "CAPTCHA_TOKEN_INVALID", "Captcha token is invalid or expired")
end
if token_record.phoneHash ~= phone_hash or token_record.ipHash ~= ip_hash then
  return res.err(403, "CAPTCHA_TOKEN_MISMATCH", "Captcha token does not match this request")
end

local ok_cooldown = limiter.hit("sms:phone:cooldown:" .. phone_hash, 1, 60)
if not ok_cooldown then
  return res.err(429, "PHONE_COOLDOWN", "Please wait before requesting another code")
end
local ok_phone_hour = limiter.hit("sms:phone:hour:" .. phone_hash, 5, 3600)
if not ok_phone_hour then
  return res.err(429, "PHONE_HOURLY_LIMITED", "Too many SMS requests for this phone")
end
local ok_phone_day = limiter.hit("sms:phone:day:" .. phone_hash, 12, 86400)
if not ok_phone_day then
  return res.err(429, "PHONE_DAILY_LIMITED", "Daily SMS limit reached for this phone")
end
local ok_ip = limiter.hit("sms:ip:hour:" .. ip_hash, 30, 3600)
if not ok_ip then
  return res.err(429, "IP_RATE_LIMITED", "Too many SMS requests from this network")
end
local ok_device = limiter.hit("sms:device:day:" .. device_id, 20, 86400)
if not ok_device then
  return res.err(429, "DEVICE_DAILY_LIMITED", "Daily SMS limit reached for this device")
end

local code = crypto.random_digits(6)
local code_hash = privacy.code_hash(phone, code)

local ep = mysql.escape("login")
local provider = mysql.escape("aliyun")
local ph = mysql.escape(phone_hash)
local ch = mysql.escape(code_hash)
local insert_result, db_err = mysql.query(string.format([[
  INSERT INTO sms_codes (phone_hash, code_hash, provider, purpose, expires_at)
  VALUES (%s, %s, %s, %s, DATE_ADD(NOW(), INTERVAL 5 MINUTE))
]], ph, ch, provider, ep))
if db_err then
  ngx.log(ngx.ERR, "sms code insert failed: ", db_err)
  return res.err(503, "DATABASE_UNAVAILABLE", "Database unavailable")
end

local send_ok, send_err = sms.send_login_code(phone, code)
if not send_ok then
  ngx.log(ngx.ERR, "sms send failed: ", send_err)
  if insert_result and insert_result.insert_id then
    mysql.query(string.format("UPDATE sms_codes SET consumed_at = NOW() WHERE id = %d", tonumber(insert_result.insert_id)))
  end
  return res.err(502, "SMS_SEND_FAILED", "SMS provider failed to send code")
end

local response = {
  cooldownSeconds = 60,
  expiresIn = 300,
  provider = "aliyun",
  phoneMask = privacy.mask_phone(phone),
}
if config.sms.dry_run then
  response.devCode = code
end

res.ok(response)
