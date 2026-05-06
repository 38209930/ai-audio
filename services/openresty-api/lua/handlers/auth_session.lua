local mysql = require "lib.mysql_client"
local req = require "lib.request"
local token = require "lib.token"
local res = require "lib.json_response"

local raw_token = req.bearer_token()
if not raw_token then
  return res.err(401, "TOKEN_REQUIRED", "Bearer token is required")
end

local payload, verify_err = token.verify(raw_token)
if not payload then
  return res.err(401, verify_err or "TOKEN_INVALID", "Token is invalid")
end

if payload.type == "guest" then
  local rows, select_err = mysql.query(string.format([[
    SELECT guest_public_id, status, trial_started_at, trial_expires_at,
      GREATEST(0, TIMESTAMPDIFF(SECOND, NOW(), trial_expires_at)) AS remaining_seconds,
      GREATEST(0, CEIL(TIMESTAMPDIFF(SECOND, NOW(), trial_expires_at) / 86400)) AS remaining_days
    FROM guest_trials
    WHERE guest_public_id = %s
    LIMIT 1
  ]], mysql.escape(payload.sub)))
  if select_err then
    ngx.log(ngx.ERR, "guest session select failed: ", select_err)
    return res.err(503, "DATABASE_UNAVAILABLE", "Database unavailable")
  end
  local trial = rows and rows[1]
  if not trial then
    return res.err(401, "SESSION_NOT_FOUND", "Guest session not found")
  end
  if trial.status ~= "active" or tonumber(trial.remaining_seconds or 0) <= 0 then
    return res.err(403, "GUEST_TRIAL_EXPIRED", "Guest trial has expired")
  end
  return res.ok({
    type = "guest",
    isGuest = true,
    id = trial.guest_public_id,
    trialStartedAt = trial.trial_started_at,
    trialExpiresAt = trial.trial_expires_at,
    remainingDays = tonumber(trial.remaining_days or 0),
  })
end

local rows, select_err = mysql.query(string.format([[
  SELECT public_id, phone_mask, status
  FROM users
  WHERE public_id = %s
  LIMIT 1
]], mysql.escape(payload.sub)))
if select_err then
  ngx.log(ngx.ERR, "user session select failed: ", select_err)
  return res.err(503, "DATABASE_UNAVAILABLE", "Database unavailable")
end
local user = rows and rows[1]
if not user or user.status ~= "active" then
  return res.err(401, "SESSION_NOT_FOUND", "User session not found")
end

res.ok({
  type = "user",
  isGuest = false,
  id = user.public_id,
  phoneMask = user.phone_mask,
})
