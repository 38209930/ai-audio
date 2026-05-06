local crypto = require "lib.crypto"

local _M = {}

function _M.mask_phone(phone)
  if not phone or #phone < 7 then
    return "***"
  end
  return phone:sub(1, 3) .. "****" .. phone:sub(-4)
end

function _M.mask_ip(ip)
  if not ip then
    return "0.0.0.*"
  end
  local a, b, c = ip:match("^(%d+)%.(%d+)%.(%d+)%.%d+$")
  if a then
    return table.concat({a, b, c, "*"}, ".")
  end
  return ip:gsub(":[%x:]+$", ":****")
end

function _M.hash(value, namespace)
  return crypto.hmac_hex(tostring(namespace or "value") .. ":" .. tostring(value or ""))
end

function _M.phone_hash(phone)
  return _M.hash(phone, "phone")
end

function _M.ip_hash(ip)
  return _M.hash(ip, "ip")
end

function _M.code_hash(phone, code)
  return _M.hash(tostring(phone or "") .. ":" .. tostring(code or ""), "sms-code")
end

return _M
