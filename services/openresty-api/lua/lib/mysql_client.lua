local mysql = require "resty.mysql"
local config = require "lib.config"

local _M = {}

local function connect()
  local db, err = mysql:new()
  if not db then
    return nil, err
  end
  db:set_timeout(1000)

  local ok, conn_err = db:connect({
    host = config.mysql.host,
    port = config.mysql.port,
    database = config.mysql.database,
    user = config.mysql.user,
    password = config.mysql.password,
    charset = "utf8mb4",
    max_packet_size = 1024 * 1024,
  })
  if not ok then
    return nil, conn_err
  end
  return db
end

local function keepalive(db)
  if db then
    db:set_keepalive(10000, 100)
  end
end

function _M.with_conn(fn)
  local db, err = connect()
  if not db then
    return nil, err
  end

  local ok, result, fn_err = pcall(fn, db)
  keepalive(db)
  if not ok then
    return nil, result
  end
  return result, fn_err
end

function _M.query(sql)
  return _M.with_conn(function(db)
    return db:query(sql)
  end)
end

function _M.escape(value)
  value = tostring(value or "")
  value = value:gsub("'", "''")
  return "'" .. value .. "'"
end

function _M.ping()
  return _M.query("SELECT 1 AS ok")
end

return _M
