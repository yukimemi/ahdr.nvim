local MiniTest = require("mini.test")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T["bundled defaults are present"] = function()
  local cfg = require("ahdr.config")
  cfg.setup()
  local names = {}
  for _, g in ipairs(cfg.for_filetype("ps1")) do
    names[g.name] = true
  end
  eq(names["default"], true)
  eq(names["wait"], true)
end

T["user generators come first and override bundled by name"] = function()
  local cfg = require("ahdr.config")
  cfg.setup({ generators = { ps1 = { { name = "default", ext = ".x", header = "MINE" } } } })

  local first
  for _, g in ipairs(cfg.for_filetype("ps1")) do
    if g.name == "default" then
      first = g
      break
    end
  end
  eq(first.header, "MINE")
  eq(first.ext, ".x")
  -- bundled entries are still appended after the user's
  eq(#cfg.for_filetype("ps1") >= 4, true)
end

T["unknown filetype yields no generators"] = function()
  local cfg = require("ahdr.config")
  cfg.setup()
  eq(cfg.for_filetype("no-such-ft"), {})
end

return T
