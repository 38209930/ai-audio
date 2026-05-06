local mysql = require "lib.mysql_client"
local req = require "lib.request"
local privacy = require "lib.privacy"
local res = require "lib.json_response"

local body, err = req.json_body()
if not body then
  return res.err(400, "INVALID_JSON", err)
end

if not body.deviceId or body.deviceId == "" then
  return res.err(400, "MISSING_DEVICE_ID", "deviceId is required")
end

local ip = req.client_ip()
local ip_hash = privacy.ip_hash(ip)
local ip_mask = privacy.mask_ip(ip)
local os_name = body.osName or "unknown"
local os_version = body.osVersion or ""
local app_version = body.appVersion or ""

local _, db_err = mysql.query(string.format([[
  INSERT INTO client_devices (device_id, os_name, os_version, app_version, last_ip_hash, last_ip_mask)
  VALUES (%s, %s, %s, %s, %s, %s)
  ON DUPLICATE KEY UPDATE os_name = VALUES(os_name), os_version = VALUES(os_version), app_version = VALUES(app_version), last_ip_hash = VALUES(last_ip_hash), last_ip_mask = VALUES(last_ip_mask), last_seen_at = NOW()
]], mysql.escape(body.deviceId), mysql.escape(os_name), mysql.escape(os_version), mysql.escape(app_version), mysql.escape(ip_hash), mysql.escape(ip_mask)))
if db_err then
  ngx.log(ngx.ERR, "device report failed: ", db_err)
  return res.err(503, "DATABASE_UNAVAILABLE", "Database unavailable")
end

res.ok({ accepted = true })

