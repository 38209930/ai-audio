local req = require "lib.request"
local captcha = require "lib.captcha"
local res = require "lib.json_response"

local body, err = req.json_body()
if not body then
  return res.err(400, "INVALID_JSON", err)
end

if not body.challengeId then
  return res.err(400, "MISSING_CHALLENGE", "challengeId is required")
end

local result, verify_err = captcha.verify(body.challengeId, body.clicks)
if not result then
  if verify_err == "CAPTCHA_EXPIRED" then
    return res.err(400, "CAPTCHA_EXPIRED", "Captcha challenge expired")
  end
  if verify_err == "CAPTCHA_USED" then
    return res.err(400, "CAPTCHA_USED", "Captcha challenge already used")
  end
  return res.err(400, verify_err or "CAPTCHA_INVALID", "Captcha verification failed")
end

res.ok(result)

