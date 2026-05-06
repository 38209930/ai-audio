local cjson = require "cjson.safe"

local _M = {}

local function request_id()
  local header_id = ngx.req.get_headers()["x-request-id"]
  if header_id and header_id ~= "" then
    return header_id
  end
  return string.format("req_%d_%d", ngx.now() * 1000, math.random(100000, 999999))
end

function _M.ok(data)
  ngx.status = ngx.HTTP_OK
  ngx.header["Content-Type"] = "application/json; charset=utf-8"
  ngx.say(cjson.encode({
    ok = true,
    data = data or cjson.empty_object,
    error = cjson.null,
    requestId = request_id(),
  }))
end

function _M.err(status, code, message)
  ngx.status = status or ngx.HTTP_BAD_REQUEST
  ngx.header["Content-Type"] = "application/json; charset=utf-8"
  ngx.say(cjson.encode({
    ok = false,
    data = cjson.null,
    error = {
      code = code or "BAD_REQUEST",
      message = message or "Bad request",
    },
    requestId = request_id(),
  }))
end

return _M

