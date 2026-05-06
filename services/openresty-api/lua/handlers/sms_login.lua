local mysql = require "lib.mysql_client"
local req = require "lib.request"
local privacy = require "lib.privacy"
local crypto = require "lib.crypto"
local limiter = require "middleware.rate_limit"
local token = require "lib.token"
local res = require "lib.json_response"

local body, err = req.json_body()
if not body then
  return res.err(400, "INVALID_JSON", err)
end

if not body.phone or not body.code then
  return res.err(400, "MISSING_FIELDS", "phone and code are required")
end

local phone = body.phone
local code = body.code
local ip = req.client_ip()
local device_id = body.deviceId or "unknown"
local os_name = body.osName or "unknown"
local os_version = body.osVersion or ""
local app_version = body.appVersion or ""
local phone_hash = privacy.phone_hash(phone)
local phone_mask = privacy.mask_phone(phone)
local ip_hash = privacy.ip_hash(ip)
local ip_mask = privacy.mask_ip(ip)

local ok_attempts = limiter.hit("sms:login:phone:" .. phone_hash, 8, 900)
if not ok_attempts then
  return res.err(429, "LOGIN_ATTEMPTS_LIMITED", "Too many login attempts")
end

local rows, select_err = mysql.query(string.format([[
  SELECT id, code_hash, failed_attempts
  FROM sms_codes
  WHERE phone_hash = %s
    AND purpose = 'login'
    AND consumed_at IS NULL
    AND expires_at > NOW()
  ORDER BY id DESC
  LIMIT 1
]], mysql.escape(phone_hash)))
if select_err then
  ngx.log(ngx.ERR, "sms code select failed: ", select_err)
  return res.err(503, "DATABASE_UNAVAILABLE", "Database unavailable")
end
if not rows or not rows[1] then
  return res.err(400, "SMS_CODE_EXPIRED", "SMS code is expired or missing")
end

local sms_row = rows[1]
if tonumber(sms_row.failed_attempts or 0) >= 5 then
  return res.err(429, "SMS_CODE_LOCKED", "SMS code is locked")
end

local expected_hash = privacy.code_hash(phone, code)
if sms_row.code_hash ~= expected_hash then
  mysql.query(string.format("UPDATE sms_codes SET failed_attempts = failed_attempts + 1 WHERE id = %d", tonumber(sms_row.id)))
  mysql.query(string.format([[
    INSERT INTO login_events (phone_hash, phone_mask, ip_hash, ip_mask, device_id, os_name, os_version, app_version, result, reason)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'failed', 'invalid_sms_code')
  ]], mysql.escape(phone_hash), mysql.escape(phone_mask), mysql.escape(ip_hash), mysql.escape(ip_mask), mysql.escape(device_id), mysql.escape(os_name), mysql.escape(os_version), mysql.escape(app_version)))
  return res.err(400, "SMS_CODE_INVALID", "SMS code is invalid")
end

local public_id = crypto.random_id("usr")
local insert_rows, insert_err = mysql.query(string.format([[
  INSERT INTO users (public_id, phone_hash, phone_mask)
  VALUES (%s, %s, %s)
  ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id), phone_mask = VALUES(phone_mask), updated_at = NOW()
]], mysql.escape(public_id), mysql.escape(phone_hash), mysql.escape(phone_mask)))
if insert_err then
  ngx.log(ngx.ERR, "user upsert failed: ", insert_err)
  return res.err(503, "DATABASE_UNAVAILABLE", "Database unavailable")
end

local user_id = tonumber(insert_rows.insert_id)
local user_rows = mysql.query(string.format("SELECT id, public_id, phone_mask FROM users WHERE id = %d LIMIT 1", user_id))
local user = user_rows and user_rows[1]
if not user then
  return res.err(503, "USER_LOAD_FAILED", "User load failed")
end

mysql.query(string.format("UPDATE sms_codes SET consumed_at = NOW() WHERE id = %d", tonumber(sms_row.id)))
mysql.query(string.format([[
  INSERT INTO login_events (user_id, phone_hash, phone_mask, ip_hash, ip_mask, device_id, os_name, os_version, app_version, result)
  VALUES (%d, %s, %s, %s, %s, %s, %s, %s, %s, 'success')
]], user_id, mysql.escape(phone_hash), mysql.escape(phone_mask), mysql.escape(ip_hash), mysql.escape(ip_mask), mysql.escape(device_id), mysql.escape(os_name), mysql.escape(os_version), mysql.escape(app_version)))
mysql.query(string.format([[
  INSERT INTO client_devices (user_id, device_id, os_name, os_version, app_version, last_ip_hash, last_ip_mask)
  VALUES (%d, %s, %s, %s, %s, %s, %s)
  ON DUPLICATE KEY UPDATE user_id = VALUES(user_id), os_name = VALUES(os_name), os_version = VALUES(os_version), app_version = VALUES(app_version), last_ip_hash = VALUES(last_ip_hash), last_ip_mask = VALUES(last_ip_mask), last_seen_at = NOW()
]], user_id, mysql.escape(device_id), mysql.escape(os_name), mysql.escape(os_version), mysql.escape(app_version), mysql.escape(ip_hash), mysql.escape(ip_mask)))

local tokens = token.issue_pair(user.public_id)
tokens.user = {
  id = user.public_id,
  phoneMask = user.phone_mask,
}

res.ok(tokens)

