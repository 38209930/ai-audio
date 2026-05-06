local config = require "lib.config"
local crypto = require "lib.crypto"

local _M = {}

function _M.issue_pair(user_public_id)
  return {
    accessToken = crypto.jwt({
      sub = user_public_id,
      type = "access",
    }, config.jwt.access_ttl),
    refreshToken = crypto.jwt({
      sub = user_public_id,
      type = "refresh",
    }, config.jwt.refresh_ttl),
    expiresIn = config.jwt.access_ttl,
  }
end

function _M.issue_guest(guest_public_id, ttl_seconds)
  local ttl = math.min(config.jwt.access_ttl, tonumber(ttl_seconds) or config.jwt.access_ttl)
  if ttl < 1 then
    ttl = 1
  end
  return {
    accessToken = crypto.jwt({
      sub = guest_public_id,
      type = "guest",
    }, ttl),
    expiresIn = ttl,
  }
end

function _M.verify(raw_token)
  return crypto.verify_jwt(raw_token)
end

return _M
