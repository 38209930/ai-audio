local cjson = require "cjson.safe"
local req = require "lib.request"
local privacy = require "lib.privacy"
local res = require "lib.json_response"

local body, err = req.json_body()
if not body then
  return res.err(400, "INVALID_JSON", err)
end

local phone = body.phone or ""
local challenge_id = string.format("cap_%d_%d", ngx.now() * 1000, math.random(100000, 999999))
local prompt = {"学", "习", "工", "具"}

ngx.shared.captcha_store:set(challenge_id, cjson.encode({
  phoneHash = privacy.pseudo_hash(phone),
  prompt = prompt,
  used = false,
}), 120)

res.ok({
  challengeId = challenge_id,
  imageBase64 = "data:image/png;base64,TODO_GENERATE_CLICK_CHARACTER_IMAGE",
  prompt = "请按顺序点击：学 习 工 具",
  expiresIn = 120,
})

