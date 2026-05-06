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

return _M
