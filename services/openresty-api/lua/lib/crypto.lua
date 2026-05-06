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

local function base64url_decode(value)
  value = tostring(value or ""):gsub("-", "+"):gsub("_", "/")
  local remainder = #value % 4
  if remainder > 0 then
    value = value .. string.rep("=", 4 - remainder)
  end
  return ngx.decode_base64(value)
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

function _M.verify_jwt(token)
  local header_part, payload_part, signature_part = tostring(token or ""):match("^([^.]+)%.([^.]+)%.([^.]+)$")
  if not header_part or not payload_part or not signature_part then
    return nil, "TOKEN_MALFORMED"
  end

  local signing_input = header_part .. "." .. payload_part
  local expected = base64url(_M.hmac_hex(signing_input, config.secrets.jwt))
  if expected ~= signature_part then
    return nil, "TOKEN_SIGNATURE_INVALID"
  end

  local payload_json = base64url_decode(payload_part)
  local payload = cjson.decode(payload_json or "")
  if not payload then
    return nil, "TOKEN_PAYLOAD_INVALID"
  end
  if payload.exp and tonumber(payload.exp) and tonumber(payload.exp) < ngx.time() then
    return nil, "TOKEN_EXPIRED"
  end
  return payload
end

return _M
