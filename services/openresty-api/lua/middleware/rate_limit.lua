local redis = require "lib.redis_client"

local _M = {}

function _M.hit(key, limit, window_seconds)
  local current, err = redis.incr_with_ttl("ai_audio:rate:" .. key, window_seconds)
  if not current then
    ngx.log(ngx.ERR, "redis rate limit failed: ", err)
    local dict = ngx.shared.rate_limit_store
    current = dict:incr(key, 1, 0, window_seconds)
    if current == 1 then
      dict:expire(key, window_seconds)
    end
  end
  return current <= limit, current
end

return _M
