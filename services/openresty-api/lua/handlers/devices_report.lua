local req = require "lib.request"
local res = require "lib.json_response"

local body, err = req.json_body()
if not body then
  return res.err(400, "INVALID_JSON", err)
end

-- Placeholder: production stores device/app metadata in MySQL.
res.ok({
  accepted = true,
})

