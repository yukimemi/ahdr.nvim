-- Eager registration so the `:Ahdr*` commands work without calling
-- `require("ahdr").setup()` (convention over configuration). `setup()` is only
-- needed to add or override generators beyond the bundled defaults.
if vim.g.loaded_ahdr then
  return
end
vim.g.loaded_ahdr = true

require("ahdr.command").register()
