local config = require "lib.config"
local mysql = require "lib.mysql_client"
local redis = require "lib.redis_client"
local res = require "lib.json_response"

local mysql_ok = false
local redis_ok = false

local mysql_result = mysql.ping()
if mysql_result then
  mysql_ok = true
end

local redis_result = redis.ping()
if redis_result then
  redis_ok = true
end

res.ok({
  service = "ai-audio-openresty-api",
  status = mysql_ok and redis_ok and "ok" or "degraded",
  version = config.api.version,
  dependencies = {
    mysql = mysql_ok and "ok" or "unavailable",
    redis = redis_ok and "ok" or "unavailable",
  },
})

