local redis = require "resty.redis"
local config = require "lib.config"

local _M = {}

local function connect()
  local red = redis:new()
  red:set_timeout(1000)

  local ok, err = red:connect(config.redis.host, config.redis.port)
  if not ok then
    return nil, err
  end

  if config.redis.password and config.redis.password ~= "" then
    local auth_ok, auth_err = red:auth(config.redis.password)
    if not auth_ok then
      return nil, auth_err
    end
  end

  if config.redis.db and config.redis.db > 0 then
    local select_ok, select_err = red:select(config.redis.db)
    if not select_ok then
      return nil, select_err
    end
  end

  return red
end

local function keepalive(red)
  if red then
    red:set_keepalive(10000, 100)
  end
end

function _M.call(command, ...)
  local red, err = connect()
  if not red then
    return nil, err
  end

  local fn = red[string.lower(command)]
  if not fn then
    keepalive(red)
    return nil, "unsupported redis command: " .. tostring(command)
  end

  local result, call_err = fn(red, ...)
  keepalive(red)
  return result, call_err
end

function _M.setex(key, ttl, value)
  return _M.call("setex", key, ttl, value)
end

function _M.get(key)
  local value, err = _M.call("get", key)
  if value == ngx.null then
    return nil, err
  end
  return value, err
end

function _M.del(key)
  return _M.call("del", key)
end

function _M.incr_with_ttl(key, ttl)
  local red, err = connect()
  if not red then
    return nil, err
  end

  local value, incr_err = red:incr(key)
  if not value then
    keepalive(red)
    return nil, incr_err
  end
  if value == 1 then
    red:expire(key, ttl)
  end
  keepalive(red)
  return value
end

function _M.ping()
  return _M.call("ping")
end

return _M
