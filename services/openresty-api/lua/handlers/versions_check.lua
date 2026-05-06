local res = require "lib.json_response"

res.ok({
  platform = ngx.var.arg_platform or "windows",
  latestVersion = "0.1.0",
  forceUpdate = false,
  downloadUrl = "https://github.com/38209930/ai-audio/releases",
  notes = "Initial commercial desktop foundation.",
})

