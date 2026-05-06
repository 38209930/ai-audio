local mysql = require "lib.mysql_client"
local res = require "lib.json_response"

local platform = ngx.var.arg_platform or "windows"
local current = ngx.var.arg_version or ""

local rows, err = mysql.query(string.format([[
  SELECT platform, version, force_update, download_url, notes_md
  FROM app_versions
  WHERE platform = %s
  ORDER BY published_at DESC, id DESC
  LIMIT 1
]], mysql.escape(platform)))
if err or not rows or not rows[1] then
  ngx.log(ngx.ERR, "version fallback used: ", err)
  return res.ok({
    platform = platform,
    currentVersion = current,
    latestVersion = "0.1.0",
    forceUpdate = false,
    downloadUrl = "https://github.com/38209930/ai-audio/releases",
    notes = "Initial commercial desktop foundation.",
    source = "fallback",
  })
end

local row = rows[1]
res.ok({
  platform = row.platform,
  currentVersion = current,
  latestVersion = row.version,
  forceUpdate = tonumber(row.force_update) == 1,
  downloadUrl = row.download_url,
  notes = row.notes_md,
  source = "mysql",
})

