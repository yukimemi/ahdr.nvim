local MiniTest = require("mini.test")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      require("ahdr.config").setup()
    end,
  },
})

local function read(p)
  local f = io.open(p, "rb")
  if not f then
    return nil
  end
  local d = f:read("*a")
  f:close()
  return d
end

local function bufdir()
  return vim.fs.dirname(vim.fs.normalize(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")))
end

-- The write is async; wait for the fully-written content (fs_open precedes
-- fs_write, so the file may briefly exist empty/partial).
local function wait_for(path, needle)
  vim.wait(2000, function()
    local d = read(path)
    return d ~= nil and d:find(needle) ~= nil
  end, 20)
  return read(path)
end

local function new_ps1(name, content)
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local src = dir .. "/" .. name
  local fd = assert(io.open(src, "w"))
  fd:write(content)
  fd:close()
  vim.cmd.edit(vim.fn.fnameescape(src))
  vim.bo.filetype = "ps1"
  vim.bo.fileformat = "unix"
end

T["generate writes header + content beside the source"] = function()
  new_ps1("foo.ps1", "Write-Host hi\n")
  require("ahdr").generate("default")

  local data = wait_for(bufdir() .. "/foo.cmd", "Write%-Host hi")
  eq(data ~= nil, true)
  eq(data:find("@powershell", 1, true) ~= nil, true) -- header
  eq(data:find("Write%-Host hi") ~= nil, true) -- body
end

T["suffix and ext shape the output filename"] = function()
  new_ps1("foo.ps1", "body-marker\n")
  require("ahdr").generate("wait") -- suffix "_w"
  eq(wait_for(bufdir() .. "/foo_w.cmd", "body%-marker") ~= nil, true)
end

T["dst is resolved relative to the source directory"] = function()
  require("ahdr.config").setup({
    generators = { ps1 = { { name = "rel", dst = "../out", ext = ".cmd", header = "HEADER" } } },
  })
  local base = vim.fn.tempname()
  vim.fn.mkdir(base .. "/src", "p")
  local src = base .. "/src/bar.ps1"
  local fd = assert(io.open(src, "w"))
  fd:write("body-marker\n")
  fd:close()
  vim.cmd.edit(vim.fn.fnameescape(src))
  vim.bo.filetype = "ps1"
  vim.bo.fileformat = "unix"

  require("ahdr").generate("rel")
  local out = vim.fs.normalize(bufdir() .. "/../out") .. "/bar.cmd"
  eq(wait_for(out, "body%-marker") ~= nil, true)
end

T["dos fileformat writes CRLF"] = function()
  new_ps1("foo.ps1", "body-marker\n")
  vim.bo.fileformat = "dos"
  require("ahdr").generate("default")
  local data = wait_for(bufdir() .. "/foo.cmd", "body%-marker")
  eq(data:find("\r\n") ~= nil, true)
end

T["unknown generator name is a no-op"] = function()
  new_ps1("foo.ps1", "x\n")
  require("ahdr").generate("does-not-exist")
  vim.wait(200)
  eq(read(bufdir() .. "/foo.cmd"), nil)
end

return T
