local _M = {}

local function env(name, default)
  local value = os.getenv(name)
  if value == nil or value == "" then
    return default
  end
  return value
end

local function env_number(name, default)
  local value = tonumber(env(name, ""))
  if value == nil then
    return default
  end
  return value
end

local function env_bool(name, default)
  local value = env(name, nil)
  if value == nil then
    return default
  end
  value = string.lower(value)
  return value == "1" or value == "true" or value == "yes"
end

_M.api = {
  env = env("API_ENV", "local"),
  version = env("API_VERSION", "0.2.0"),
}

_M.secrets = {
  hmac = env("HMAC_SECRET", "dev-hmac-secret-change-me"),
  jwt = env("JWT_SECRET", "dev-jwt-secret-change-me"),
}

_M.jwt = {
  access_ttl = env_number("JWT_ACCESS_TTL_SECONDS", 7200),
  refresh_ttl = env_number("JWT_REFRESH_TTL_SECONDS", 2592000),
}

_M.mysql = {
  host = env("MYSQL_HOST", "mysql"),
  port = env_number("MYSQL_PORT", 3306),
  database = env("MYSQL_DATABASE", "ai_audio"),
  user = env("MYSQL_USER", "ai_audio"),
  password = env("MYSQL_PASSWORD", "ai_audio_dev"),
}

_M.redis = {
  host = env("REDIS_HOST", "redis"),
  port = env_number("REDIS_PORT", 6379),
  password = env("REDIS_PASSWORD", ""),
  db = env_number("REDIS_DB", 0),
}

_M.sms = {
  dry_run = env_bool("SMS_DRY_RUN", true),
  provider = "aliyun",
  aliyun = {
    access_key_id = env("ALIYUN_SMS_ACCESS_KEY_ID", ""),
    access_key_secret = env("ALIYUN_SMS_ACCESS_KEY_SECRET", ""),
    sign_name = env("ALIYUN_SMS_SIGN_NAME", ""),
    template_code = env("ALIYUN_SMS_TEMPLATE_CODE", ""),
    region_id = env("ALIYUN_SMS_REGION_ID", "cn-hangzhou"),
  },
}

return _M
