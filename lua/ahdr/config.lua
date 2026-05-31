local M = {}

---@class ahdr.Generator
---@field name string     Identifier used by `:Ahdr {name}`.
---@field ext string      Output file extension (e.g. ".cmd").
---@field header string   Text prepended to the buffer content.
---@field prefix? string  Output filename prefix. Default "".
---@field suffix? string  Output filename suffix. Default "".
---@field dst? string     Output directory, absolute or relative to the source file. Default: alongside the source.

---@class ahdr.Options
---@field notify boolean
---@field log_level "trace"|"debug"|"info"|"warn"|"error"
---@field generators table<string, ahdr.Generator[]>  filetype -> generators

-- A PowerShell/cmd polyglot launcher header. `gc ... | ? readcount > N` skips
-- the leading cmd lines so PowerShell only runs the script body.
local PS1_DEFAULT = [[
@set __SCRIPTPATH=%~f0&@powershell -NoProfile -ExecutionPolicy ByPass -InputFormat None "$s=[scriptblock]::create((gc -enc utf8 -li \"%~f0\"|?{$_.readcount -gt 2})-join\"`n\");&$s" %*
@exit /b %errorlevel%
]]

local PS1_PAUSE = [[
@set __SCRIPTPATH=%~f0&@powershell -NoProfile -ExecutionPolicy ByPass -InputFormat None "$s=[scriptblock]::create((gc -enc utf8 -li \"%~f0\"|?{$_.readcount -gt 2})-join\"`n\");&$s" %*&@pause
@exit /b %errorlevel%
]]

local PS1_WAIT = [[
@set __SCRIPTPATH=%~f0&@powershell -NoProfile -ExecutionPolicy ByPass -InputFormat None "$s=[scriptblock]::create((gc -enc utf8 -li \"%~f0\"|?{$_.readcount -gt 2})-join\"`n\");&$s" %*&@ping -n 30 localhost > nul
@exit /b %errorlevel%
]]

local JS_DEFAULT = [[
@set @junk=1 /*
@cscript //nologo //e:jscript "%~f0" %*
@exit /b %errorlevel%
*/
]]

local JS_PAUSE = [[
@set @junk=1 /*
@cscript //nologo //e:jscript "%~f0" %*
@pause
@exit /b %errorlevel%
*/
]]

local JS_WAIT = [[
@set @junk=1 /*
@cscript //nologo //e:jscript "%~f0" %*
@ping -n 30 localhost > nul
@exit /b %errorlevel%
*/
]]

local DOSBATCH_ADMIN = [[
@openfiles > nul 2>&1
@if %errorlevel% equ 0 goto :ALREADY_ADMIN_PRIVILEGE
@powershell.exe -Command Start-Process \'%~f0\' %* -verb runas
@exit /b %errorlevel%
:ALREADY_ADMIN_PRIVILEGE
]]

M.defaults = {
  notify = false,
  log_level = "warn",
  generators = {
    ps1 = {
      { name = "default", ext = ".cmd", header = PS1_DEFAULT },
      { name = "pause", suffix = "_p", ext = ".cmd", header = PS1_PAUSE },
      { name = "wait", suffix = "_w", ext = ".cmd", header = PS1_WAIT },
    },
    javascript = {
      { name = "default", ext = ".cmd", header = JS_DEFAULT },
      { name = "pause", suffix = "_p", ext = ".cmd", header = JS_PAUSE },
      { name = "wait", suffix = "_w", ext = ".cmd", header = JS_WAIT },
    },
    dosbatch = {
      { name = "admin", suffix = "_a", ext = ".bat", header = DOSBATCH_ADMIN },
    },
  },
}

M.options = vim.deepcopy(M.defaults)

---@param opts? ahdr.Options
function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend("force", M.defaults, opts)

  -- `generators` is a map of lists; tbl_deep_extend would merge the lists by
  -- index. Rebuild it so a filetype's user generators come first (overriding by
  -- name) followed by the bundled defaults.
  M.options.generators = {}
  for ft, list in pairs(M.defaults.generators) do
    M.options.generators[ft] = vim.deepcopy(list)
  end
  for ft, list in pairs(opts.generators or {}) do
    local merged = vim.deepcopy(list)
    vim.list_extend(merged, M.options.generators[ft] or {})
    M.options.generators[ft] = merged
  end
end

---Generators for a filetype.
---@param ft string
---@return ahdr.Generator[]
function M.for_filetype(ft)
  return M.options.generators[ft] or {}
end

return M
