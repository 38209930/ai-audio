local cjson = require "cjson.safe"
local resty_string = require "resty.string"
local config = require "lib.config"

local ok_hmac, openssl_hmac = pcall(require, "resty.openssl.hmac")

local _M = {}

local function to_hex(binary)
  return resty_string.to_hex(binary or "")
end

function _M.random_digits(length)
  local chars = {}
  for _ = 1, length do
    chars[#chars + 1] = tostring(math.random(0, 9))
  end
  return table.concat(chars)
end

function _M.random_id(prefix)
  return string.format("%s_%d_%d", prefix, ngx.now() * 1000, math.random(100000, 999999))
end

function _M.hmac_hex(value, secret)
  value = tostring(value or "")
  secret = secret or config.secrets.hmac

  if ok_hmac then
    local h, err = openssl_hmac.new(secret, "sha256")
    if not h then
      return nil, err
    end
    local ok, update_err = h:update(value)
    if not ok then
      return nil, update_err
    end
    local digest, final_err = h:final()
    if not digest then
      return nil, final_err
    end
    return to_hex(digest)
  end

  local digest = ngx.hmac_sha1(secret, value)
  return (to_hex(digest) .. string.rep("0", 64)):sub(1, 64)
end

local function base64url(value)
  return ngx.encode_base64(value):gsub("+", "-"):gsub("/", "_"):gsub("=+$", "")
end

function _M.jwt(payload, ttl_seconds)
  local header = { alg = "HS256", typ = "JWT" }
  payload = payload or {}
  payload.iat = ngx.time()
  payload.exp = payload.iat + ttl_seconds

  local signing_input = base64url(cjson.encode(header)) .. "." .. base64url(cjson.encode(payload))
  local signature = _M.hmac_hex(signing_input, config.secrets.jwt)
  return signing_input .. "." .. base64url(signature)
end

return _M
