local mysql = require "lib.mysql_client"
local req = require "lib.request"
local privacy = require "lib.privacy"
local crypto = require "lib.crypto"
local token = require "lib.token"
local res = require "lib.json_response"

local body, err = req.json_body()
if not body then
  return res.err(400, "INVALID_JSON", err)
end

if not body.deviceId or body.deviceId == "" then
  return res.err(400, "MISSING_DEVICE_ID", "deviceId is required")
end

local device_id = body.deviceId
local os_name = body.osName or "unknown"
local os_version = body.osVersion or ""
local app_version = body.appVersion or ""
local ip = req.client_ip()
local ip_hash = privacy.ip_hash(ip)
local ip_mask = privacy.mask_ip(ip)

local function load_trial()
  local rows, select_err = mysql.query(string.format([[
    SELECT id, device_id, guest_public_id, status, trial_started_at, trial_expires_at,
      GREATEST(0, TIMESTAMPDIFF(SECOND, NOW(), trial_expires_at)) AS remaining_seconds,
      GREATEST(0, CEIL(TIMESTAMPDIFF(SECOND, NOW(), trial_expires_at) / 86400)) AS remaining_days
    FROM guest_trials
    WHERE device_id = %s
    LIMIT 1
  ]], mysql.escape(device_id)))
  if select_err then
    return nil, select_err
  end
  return rows and rows[1]
end

local trial, load_err = load_trial()
if load_err then
  ngx.log(ngx.ERR, "guest trial select failed: ", load_err)
  return res.err(503, "DATABASE_UNAVAILABLE", "Database unavailable")
end

if not trial then
  local guest_public_id = crypto.random_id("gst")
  local _, insert_err = mysql.query(string.format([[
    INSERT INTO guest_trials (
      device_id, guest_public_id, trial_expires_at, ip_hash, ip_mask, os_name, os_version, app_version
    )
    VALUES (%s, %s, DATE_ADD(NOW(), INTERVAL 30 DAY), %s, %s, %s, %s, %s)
  ]],
    mysql.escape(device_id),
    mysql.escape(guest_public_id),
    mysql.escape(ip_hash),
    mysql.escape(ip_mask),
    mysql.escape(os_name),
    mysql.escape(os_version),
    mysql.escape(app_version)
  ))
  if insert_err then
    ngx.log(ngx.ERR, "guest trial insert failed: ", insert_err)
    return res.err(503, "DATABASE_UNAVAILABLE", "Database unavailable")
  end
  trial, load_err = load_trial()
  if load_err or not trial then
    return res.err(503, "GUEST_TRIAL_LOAD_FAILED", "Guest trial load failed")
  end
else
  mysql.query(string.format([[
    UPDATE guest_trials
    SET last_seen_at = NOW(), ip_hash = %s, ip_mask = %s, os_name = %s, os_version = %s, app_version = %s
    WHERE id = %d
  ]],
    mysql.escape(ip_hash),
    mysql.escape(ip_mask),
    mysql.escape(os_name),
    mysql.escape(os_version),
    mysql.escape(app_version),
    tonumber(trial.id)
  ))
end

local remaining_seconds = tonumber(trial.remaining_seconds or 0)
if trial.status ~= "active" or remaining_seconds <= 0 then
  return res.err(403, "GUEST_TRIAL_EXPIRED", "Guest trial has expired")
end

local issued = token.issue_guest(trial.guest_public_id, remaining_seconds)
issued.guest = {
  id = trial.guest_public_id,
  trialStartedAt = trial.trial_started_at,
  trialExpiresAt = trial.trial_expires_at,
  remainingDays = tonumber(trial.remaining_days or 0),
}

res.ok(issued)
