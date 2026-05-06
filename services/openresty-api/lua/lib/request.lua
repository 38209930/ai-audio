local cjson = require "cjson.safe"

local _M = {}

function _M.json_body()
  ngx.req.read_body()
  local body = ngx.req.get_body_data()
  if not body or body == "" then
    return {}
  end
  local decoded, err = cjson.decode(body)
  if not decoded then
    return nil, err
  end
  return decoded
end

function _M.client_ip()
  local headers = ngx.req.get_headers()
  local forwarded = headers["x-forwarded-for"]
  if forwarded and forwarded ~= "" then
    return forwarded:match("^%s*([^,%s]+)")
  end
  return ngx.var.remote_addr or "0.0.0.0"
end

function _M.bearer_token()
  local auth = ngx.req.get_headers()["authorization"] or ngx.req.get_headers()["Authorization"]
  if not auth or auth == "" then
    return nil
  end
  return auth:match("^[Bb]earer%s+(.+)$")
end

return _M
