local req = require "lib.request"
local privacy = require "lib.privacy"
local res = require "lib.json_response"

local body, err = req.json_body()
if not body then
  return res.err(400, "INVALID_JSON", err)
end

if not body.phone or not body.code then
  return res.err(400, "MISSING_FIELDS", "phone and code are required")
end

-- Placeholder: production must verify code from MySQL/Redis and issue signed JWTs.
res.ok({
  accessToken = "jwt_access_placeholder",
  refreshToken = "jwt_refresh_placeholder",
  user = {
    id = "usr_placeholder",
    phoneMask = privacy.mask_phone(body.phone),
  },
})

