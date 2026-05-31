local M = {}

---Configure ahdr (register generators). Commands work without this; `setup()`
---is only needed to add or override generators.
---@param opts? ahdr.Options
function M.setup(opts)
  require("ahdr.config").setup(opts)
  require("ahdr.command").register()
end

-- Convenience Lua API mirroring the `:Ahdr*` commands.

---@param name string
---@param opts? { quiet?: boolean }
function M.generate(name, opts)
  require("ahdr.ahdr").generate(name, opts)
end

---@param name string
function M.watch(name)
  require("ahdr.watch").watch(name)
end

function M.unwatch()
  require("ahdr.watch").unwatch()
end

return M
