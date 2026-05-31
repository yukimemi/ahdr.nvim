local M = {}

local function names_for_current_ft()
  local out = {}
  for _, g in ipairs(require("ahdr.config").for_filetype(vim.bo.filetype)) do
    out[#out + 1] = g.name
  end
  return out
end

-- Completion: generator names available for the current buffer's filetype.
local function complete(arglead)
  return vim.tbl_filter(function(n)
    return n:find(arglead, 1, true) == 1
  end, names_for_current_ft())
end

---Register the `:Ahdr*` user commands. Safe to call more than once.
function M.register()
  vim.api.nvim_create_user_command("Ahdr", function(a)
    require("ahdr.ahdr").generate(a.args)
  end, { nargs = 1, complete = complete, desc = "ahdr: generate a file from the current buffer" })

  vim.api.nvim_create_user_command("AhdrWatch", function(a)
    require("ahdr.watch").watch(a.args)
  end, { nargs = 1, complete = complete, desc = "ahdr: regenerate on every save (current buffer)" })

  vim.api.nvim_create_user_command("AhdrUnwatch", function()
    require("ahdr.watch").unwatch()
  end, { desc = "ahdr: stop regenerating on save" })
end

return M
