local cjson = require "cjson.safe"
local mysql = require "lib.mysql_client"
local res = require "lib.json_response"

local fallback_models = {
  {
    id = "Systran/faster-whisper-large-v3",
    displayName = "faster-whisper large-v3",
    task = "asr",
    license = "MIT",
    commercialUse = "allowed",
    manualDownloadUrl = "https://hf-mirror.com/Systran/faster-whisper-large-v3/tree/main",
    requiredFiles = {"config.json", "model.bin", "preprocessor_config.json", "tokenizer.json", "vocabulary.json"},
    recommendedHardware = "NVIDIA GPU recommended; CPU possible but slow",
  },
  {
    id = "Systran/faster-whisper-medium",
    displayName = "faster-whisper medium",
    task = "asr",
    license = "MIT",
    commercialUse = "allowed",
    manualDownloadUrl = "https://hf-mirror.com/Systran/faster-whisper-medium/tree/main",
    requiredFiles = {"config.json", "model.bin", "preprocessor_config.json", "tokenizer.json", "vocabulary.json"},
    recommendedHardware = "CPU or GPU",
  },
}

local rows, err = mysql.query([[
  SELECT model_id, display_name, task, license, commercial_use, manual_download_url, required_files, recommended_hardware
  FROM model_catalog
  WHERE enabled = 1
  ORDER BY id ASC
]])
if err or not rows then
  ngx.log(ngx.ERR, "model catalog fallback used: ", err)
  return res.ok({ models = fallback_models, source = "fallback" })
end

local models = {}
for _, row in ipairs(rows) do
  models[#models + 1] = {
    id = row.model_id,
    displayName = row.display_name,
    task = row.task,
    license = row.license,
    commercialUse = row.commercial_use,
    manualDownloadUrl = row.manual_download_url,
    requiredFiles = cjson.decode(row.required_files or "[]") or {},
    recommendedHardware = row.recommended_hardware,
  }
end

res.ok({ models = models, source = "mysql" })

