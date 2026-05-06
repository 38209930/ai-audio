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

function _M.pseudo_hash(value)
  -- Placeholder for HMAC-SHA256(value, server_secret).
  -- Production implementation must use resty.openssl.hmac or equivalent.
  value = tostring(value or "")
  return "hash_pending_" .. tostring(#value)
end

return _M

