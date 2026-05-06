local req = require "lib.request"
local privacy = require "lib.privacy"
local captcha = require "lib.captcha"
local limiter = require "middleware.rate_limit"
local res = require "lib.json_response"

local body, err = req.json_body()
if not body then
  return res.err(400, "INVALID_JSON", err)
end

local phone = body.phone or ""
local ip = req.client_ip()
local phone_hash = privacy.phone_hash(phone)
local ip_hash = privacy.ip_hash(ip)

local ok_ip = limiter.hit("captcha:ip:" .. ip_hash, 30, 3600)
if not ok_ip then
  return res.err(429, "CAPTCHA_IP_RATE_LIMITED", "Too many captcha requests from this network")
end

local result, create_err = captcha.create(phone_hash, ip_hash)
if not result then
  ngx.log(ngx.ERR, "captcha create failed: ", create_err)
  return res.err(503, "CAPTCHA_CREATE_FAILED", "Captcha service unavailable")
end

res.ok(result)

