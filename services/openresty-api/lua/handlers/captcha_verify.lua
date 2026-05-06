local cjson = require "cjson.safe"
local req = require "lib.request"
local res = require "lib.json_response"

local body, err = req.json_body()
if not body then
  return res.err(400, "INVALID_JSON", err)
end

local challenge_id = body.challengeId
if not challenge_id then
  return res.err(400, "MISSING_CHALLENGE", "challengeId is required")
end

local raw = ngx.shared.captcha_store:get(challenge_id)
if not raw then
  return res.err(400, "CAPTCHA_EXPIRED", "Captcha challenge expired")
end

local challenge = cjson.decode(raw)
if challenge.used then
  return res.err(400, "CAPTCHA_USED", "Captcha challenge already used")
end

-- Placeholder: production must validate ordered click coordinates against server-side positions.
challenge.used = true
ngx.shared.captcha_store:set(challenge_id, cjson.encode(challenge), 10)

res.ok({
  captchaToken = "ct_" .. challenge_id,
  expiresIn = 300,
})

