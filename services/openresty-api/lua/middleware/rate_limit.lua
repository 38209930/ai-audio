local _M = {}

local dict = ngx.shared.rate_limit_store

function _M.hit(key, limit, window_seconds)
  local current = dict:incr(key, 1, 0, window_seconds)
  if current == 1 then
    dict:expire(key, window_seconds)
  end
  return current <= limit, current
end

return _M

