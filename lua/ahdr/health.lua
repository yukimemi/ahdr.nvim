local M = {}

local h = vim.health
local start = h.start or h.report_start
local ok = h.ok or h.report_ok
local info = h.info or h.report_info
local warn = h.warn or h.report_warn

function M.check()
  start("ahdr")

  if vim.fn.has("nvim-0.10") == 1 then
    ok("Neovim >= 0.10")
  else
    warn("Neovim 0.10+ recommended (vim.uv)")
  end

  local generators = require("ahdr.config").options.generators or {}
  local fts = vim.tbl_keys(generators)
  table.sort(fts)
  if #fts == 0 then
    warn("no generators configured")
  else
    ok(("generators for %d filetype(s)"):format(#fts))
    for _, ft in ipairs(fts) do
      local names = {}
      for _, g in ipairs(generators[ft]) do
        names[#names + 1] = g.name
      end
      info(("- %s: %s"):format(ft, table.concat(names, ", ")))
    end
  end
end

return M
