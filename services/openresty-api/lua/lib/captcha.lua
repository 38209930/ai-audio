local cjson = require "cjson.safe"
local crypto = require "lib.crypto"
local redis = require "lib.redis_client"

local _M = {}

local CHARS = {"学", "习", "工", "具", "视", "频", "字", "幕", "音", "频", "方", "案", "模", "型", "程", "序"}
local WIDTH = 360
local HEIGHT = 160
local TTL = 120
local TOKEN_TTL = 300
local TOLERANCE = 26

local function sample_chars(count)
  local picked = {}
  local used = {}
  while #picked < count do
    local index = math.random(1, #CHARS)
    if not used[index] then
      used[index] = true
      picked[#picked + 1] = CHARS[index]
    end
  end
  return picked
end

local function positions_for(chars)
  local points = {}
  for index, char in ipairs(chars) do
    local x = 48 + (index - 1) * 78 + math.random(-14, 14)
    local y = 62 + math.random(-24, 34)
    points[#points + 1] = { char = char, x = x, y = y }
  end
  return points
end

local function svg(points)
  local parts = {
    string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">', WIDTH, HEIGHT, WIDTH, HEIGHT),
    '<rect width="100%" height="100%" fill="#f8fafc"/>',
    '<path d="M0 35 C80 10 130 80 210 40 S310 20 360 58" fill="none" stroke="#cbd5e1" stroke-width="2"/>',
    '<path d="M0 118 C75 150 145 96 225 128 S315 145 360 112" fill="none" stroke="#d1d5db" stroke-width="2"/>',
  }
  for i = 1, 18 do
    parts[#parts + 1] = string.format('<circle cx="%d" cy="%d" r="%d" fill="#e2e8f0" opacity="0.75"/>', math.random(8, WIDTH - 8), math.random(8, HEIGHT - 8), math.random(1, 3))
  end
  for index, point in ipairs(points) do
    local rotate = math.random(-18, 18)
    parts[#parts + 1] = string.format(
      '<text x="%d" y="%d" text-anchor="middle" dominant-baseline="middle" font-family="Microsoft YaHei, PingFang SC, sans-serif" font-size="38" font-weight="700" fill="#111827" transform="rotate(%d %d %d)">%s</text>',
      point.x, point.y, rotate, point.x, point.y, point.char
    )
    parts[#parts + 1] = string.format('<text x="%d" y="%d" font-family="Arial" font-size="10" fill="#64748b">%d</text>', point.x + 20, point.y - 25, index)
  end
  parts[#parts + 1] = "</svg>"
  return table.concat(parts)
end

function _M.create(phone_hash, ip_hash)
  local chars = sample_chars(4)
  local points = positions_for(chars)
  local challenge_id = crypto.random_id("cap")
  local prompt = "请按顺序点击：" .. table.concat(chars, " ")
  local record = {
    phoneHash = phone_hash,
    ipHash = ip_hash,
    prompt = prompt,
    answer = points,
    failedAttempts = 0,
    used = false,
  }

  local ok, err = redis.setex("ai_audio:captcha:challenge:" .. challenge_id, TTL, cjson.encode(record))
  if not ok then
    return nil, err
  end

  return {
    challengeId = challenge_id,
    imageBase64 = "data:image/svg+xml;base64," .. ngx.encode_base64(svg(points)),
    prompt = prompt,
    expiresIn = TTL,
  }
end

local function distance(a, b)
  local dx = tonumber(a.x or 0) - tonumber(b.x or 0)
  local dy = tonumber(a.y or 0) - tonumber(b.y or 0)
  return math.sqrt(dx * dx + dy * dy)
end

function _M.verify(challenge_id, clicks)
  local key = "ai_audio:captcha:challenge:" .. tostring(challenge_id or "")
  local raw, err = redis.get(key)
  if not raw then
    return nil, err or "CAPTCHA_EXPIRED"
  end

  local record = cjson.decode(raw)
  if not record or record.used then
    return nil, "CAPTCHA_USED"
  end
  if type(clicks) ~= "table" or #clicks ~= #record.answer then
    record.failedAttempts = (record.failedAttempts or 0) + 1
    redis.setex(key, TTL, cjson.encode(record))
    return nil, "CAPTCHA_CLICK_COUNT_INVALID"
  end

  for index, answer in ipairs(record.answer) do
    if distance(clicks[index], answer) > TOLERANCE then
      record.failedAttempts = (record.failedAttempts or 0) + 1
      if record.failedAttempts >= 5 then
        redis.del(key)
      else
        redis.setex(key, TTL, cjson.encode(record))
      end
      return nil, "CAPTCHA_COORDINATE_INVALID"
    end
  end

  redis.del(key)
  local token = crypto.random_id("ct")
  local token_record = {
    phoneHash = record.phoneHash,
    ipHash = record.ipHash,
    challengeId = challenge_id,
  }
  local ok, set_err = redis.setex("ai_audio:captcha:token:" .. token, TOKEN_TTL, cjson.encode(token_record))
  if not ok then
    return nil, set_err
  end

  return {
    captchaToken = token,
    expiresIn = TOKEN_TTL,
  }
end

function _M.consume_token(token)
  local key = "ai_audio:captcha:token:" .. tostring(token or "")
  local raw = redis.get(key)
  if not raw then
    return nil, "CAPTCHA_TOKEN_EXPIRED"
  end
  redis.del(key)
  return cjson.decode(raw)
end

return _M
