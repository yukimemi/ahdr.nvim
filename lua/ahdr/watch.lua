local M = {}

local PREFIX = "ahdr_watch_"

---Regenerate `name` on every save of the current buffer (buffer-local).
---@param name string
function M.watch(name)
  local buf = vim.api.nvim_get_current_buf()
  local group = vim.api.nvim_create_augroup(PREFIX .. buf, { clear = true })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    buffer = buf,
    callback = function()
      require("ahdr.ahdr").generate(name, { quiet = true })
    end,
  })
  require("ahdr.log").echo(("watching: regenerate '%s' on save"):format(name))
end

---Stop regenerating on save for the current buffer.
function M.unwatch()
  local buf = vim.api.nvim_get_current_buf()
  pcall(vim.api.nvim_del_augroup_by_name, PREFIX .. buf)
  require("ahdr.log").echo("stopped watching")
end

return M
