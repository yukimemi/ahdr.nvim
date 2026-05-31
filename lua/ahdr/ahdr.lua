local M = {}

local uv = vim.uv

local function is_absolute(p)
  return p:match("^/") ~= nil or p:match("^%a:/") ~= nil
end

-- Resolve a generator `dst` (absolute, or relative to the source dir).
local function resolve_dst(dst, srcdir)
  if not dst or dst == "" then
    return srcdir
  end
  dst = vim.fs.normalize(dst)
  if is_absolute(dst) then
    return dst
  end
  return vim.fs.normalize(srcdir .. "/" .. dst)
end

---@param ft string
---@param name string
---@return ahdr.Generator|nil
local function find(ft, name)
  for _, g in ipairs(require("ahdr.config").for_filetype(ft)) do
    if g.name == name then
      return g
    end
  end
  return nil
end

local function write_async(path, data, cb)
  uv.fs_open(path, "w", 420, function(oerr, fd) -- 0644
    if oerr or not fd then
      return cb(false)
    end
    uv.fs_write(fd, data, -1, function(werr)
      uv.fs_close(fd, function()
        cb(not werr)
      end)
    end)
  end)
end

---Generate the output file for generator `name` from the current buffer.
---The write is asynchronous so a watched save is never blocked.
---@param name string
---@param opts? { quiet?: boolean }  quiet suppresses the success notification
function M.generate(name, opts)
  opts = opts or {}
  local log = require("ahdr.log")
  local ft = vim.bo.filetype
  local g = find(ft, name)
  if not g then
    log.echo(("no generator '%s' for filetype '%s'"):format(name, ft == "" and "(none)" or ft), vim.log.levels.WARN)
    return
  end

  local src = vim.api.nvim_buf_get_name(0)
  if src == "" then
    log.echo("the current buffer has no file name", vim.log.levels.WARN)
    return
  end
  src = vim.fs.normalize(vim.fn.fnamemodify(src, ":p"))

  local srcdir = vim.fs.dirname(src)
  local stem = vim.fn.fnamemodify(src, ":t:r")
  local outname = (g.prefix or "") .. stem .. (g.suffix or "") .. (g.ext or "")
  local outdir = resolve_dst(g.dst, srcdir)
  local outpath = outdir .. "/" .. outname

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local body = (g.header or "") .. "\n" .. table.concat(lines, "\n")
  if vim.bo.fileformat == "dos" then
    body = body:gsub("\n", "\r\n")
  end

  vim.fn.mkdir(outdir, "p") -- sync, main thread, cheap
  write_async(outpath, body, function(ok)
    vim.schedule(function()
      if ok then
        if opts.quiet then
          log.info("wrote " .. outpath)
        else
          log.echo("wrote " .. outpath)
        end
      else
        log.echo("failed to write " .. outpath, vim.log.levels.ERROR)
      end
    end)
  end)
end

return M
