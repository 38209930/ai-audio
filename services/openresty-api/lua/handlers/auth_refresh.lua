local res = require "lib.json_response"

res.err(501, "NOT_IMPLEMENTED", "Refresh token endpoint is reserved for the next auth iteration")
