local cjson = require "cjson.safe"
local config = require "lib.config"

local ok_http, http = pcall(require, "resty.http")

local _M = {}

function _M.is_configured()
  if config.sms.dry_run then
    return true
  end
  local aliyun = config.sms.aliyun
  return aliyun.access_key_id ~= ""
    and aliyun.access_key_secret ~= ""
    and aliyun.sign_name ~= ""
    and aliyun.template_code ~= ""
end

local function percent_encode(value)
  return ngx.escape_uri(tostring(value or ""))
    :gsub("%+", "%%20")
    :gsub("%*", "%%2A")
    :gsub("%%7E", "~")
end

local function canonical_query(params)
  local keys = {}
  for key in pairs(params) do
    keys[#keys + 1] = key
  end
  table.sort(keys)

  local parts = {}
  for _, key in ipairs(keys) do
    parts[#parts + 1] = percent_encode(key) .. "=" .. percent_encode(params[key])
  end
  return table.concat(parts, "&")
end

local function signature(secret, query)
  local string_to_sign = "POST&%2F&" .. percent_encode(query)
  return ngx.encode_base64(ngx.hmac_sha1(secret .. "&", string_to_sign))
end

local function utc_timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

function _M.send_login_code(phone, code)
  if config.sms.dry_run then
    ngx.log(ngx.INFO, "SMS dry-run enabled; code generated for masked phone only")
    return true, { provider = "aliyun", dryRun = true }
  end

  local aliyun = config.sms.aliyun
  if aliyun.access_key_id == "" or aliyun.access_key_secret == "" or aliyun.sign_name == "" or aliyun.template_code == "" then
    return nil, "SMS_PROVIDER_NOT_CONFIGURED"
  end
  if not ok_http then
    return nil, "lua-resty-http is required for Aliyun SMS"
  end

  local params = {
    AccessKeyId = aliyun.access_key_id,
    Action = "SendSms",
    Format = "JSON",
    PhoneNumbers = phone,
    RegionId = aliyun.region_id,
    SignName = aliyun.sign_name,
    SignatureMethod = "HMAC-SHA1",
    SignatureNonce = tostring(ngx.now()) .. tostring(math.random(100000, 999999)),
    SignatureVersion = "1.0",
    TemplateCode = aliyun.template_code,
    TemplateParam = cjson.encode({ code = code }),
    Timestamp = utc_timestamp(),
    Version = "2017-05-25",
  }
  local query = canonical_query(params)
  params.Signature = signature(aliyun.access_key_secret, query)
  local body = canonical_query(params)

  local client = http.new()
  client:set_timeout(3000)
  local response, err = client:request_uri("https://dysmsapi.aliyuncs.com/", {
    method = "POST",
    body = body,
    headers = {
      ["Content-Type"] = "application/x-www-form-urlencoded",
    },
    ssl_verify = true,
  })
  if not response then
    return nil, err
  end

  local decoded = cjson.decode(response.body or "{}") or {}
  if response.status ~= 200 or decoded.Code ~= "OK" then
    return nil, decoded.Message or ("Aliyun SMS HTTP " .. tostring(response.status))
  end
  return true, { provider = "aliyun", dryRun = false, requestId = decoded.RequestId }
end

return _M
