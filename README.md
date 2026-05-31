<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/yukimemi/ahdr.nvim/main/assets/logo-dark.svg">
  <img src="https://raw.githubusercontent.com/yukimemi/ahdr.nvim/main/assets/logo.svg" alt="ahdr — header-stamped launcher files" width="520">
</picture>

<p><em>header-stamped launcher files.</em></p>

[![CI](https://github.com/yukimemi/ahdr.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/yukimemi/ahdr.nvim/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/yukimemi/ahdr.nvim/blob/main/LICENSE)
[![Neovim 0.10+](https://img.shields.io/badge/Neovim-0.10+-57A143?logo=neovim&logoColor=white)](https://neovim.io)

</div>

Generate a derived file from the current buffer by prepending a header and
reshaping the name — most often a PowerShell/cmd polyglot launcher (`foo.ps1` →
`foo.cmd` that bootstraps PowerShell and runs the script). A pure-Lua,
Neovim-only rewrite of [ahdr.vim](https://github.com/yukimemi/ahdr.vim) (no Deno
/ denops dependency); configured with a Lua table instead of a TOML file.

## Requirements

- Neovim >= 0.10 (`vim.uv`)

## Install

With [rvpm](https://github.com/yukimemi/rvpm) (recommended):

```sh
rvpm add yukimemi/ahdr.nvim --on-cmd '/^Ahdr.*$/'
```

Or in `config.toml`:

```toml
[[plugins]]
url = "https://github.com/yukimemi/ahdr.nvim"
on_cmd = ["/^Ahdr.*$/"]
```

> rvpm doesn't auto-run `setup()` — to register custom generators, call `require("ahdr").setup({ ... })` from a hook file (`plugins/github.com/yukimemi/ahdr.nvim/after.lua`). The bundled generators work without it.

Or with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "yukimemi/ahdr.nvim",
  cmd = { "Ahdr", "AhdrWatch", "AhdrUnwatch" },
  opts = {},
}
```

`opts` is passed straight to `require("ahdr").setup()`.

## Usage

With a `.ps1` buffer open:

```vim
:Ahdr default      " writes foo.cmd (a PowerShell launcher) next to foo.ps1
:Ahdr wait         " foo_w.cmd, pausing 30s after the script
:AhdrWatch default " regenerate foo.cmd on every save of this buffer
:AhdrUnwatch       " stop watching
```

`:Ahdr <Tab>` completes the generators available for the current filetype.

## Configuration

Generators are keyed by filetype. The plugin ships defaults for `ps1`,
`javascript`, and `dosbatch`; `setup()` adds your own (a filetype's user
generators come first and override the defaults by name):

```lua
require("ahdr").setup({
  notify = false,
  log_level = "warn",
  generators = {
    ps1 = {
      {
        name = "default",
        prefix = "",        -- output filename prefix (default "")
        suffix = "",        -- output filename suffix (default "")
        ext = ".cmd",       -- output extension
        dst = "../cmd",     -- output dir: absolute, or relative to the source (default: alongside it)
        header = [[
@set __SCRIPTPATH=%~f0&@powershell -NoProfile -ExecutionPolicy ByPass -InputFormat None "$s=[scriptblock]::create((gc -enc utf8 -li \"%~f0\"|?{$_.readcount -gt 2})-join\"`n\");&$s" %*
@exit /b %errorlevel%
]],
      },
    },
  },
})
```

The output path is `<dst>/<prefix><source-stem><suffix><ext>` and the file is
`header` + the current buffer (CRLF when the buffer's `fileformat` is `dos`).

## Commands

| Command | Action |
| --- | --- |
| `:Ahdr {name}` | Generate the file for generator `{name}` |
| `:AhdrWatch {name}` | Regenerate `{name}` on every save of the current buffer |
| `:AhdrUnwatch` | Stop regenerating on save |

## Lua API

```lua
local ahdr = require("ahdr")
ahdr.generate("default")
ahdr.watch("default")
ahdr.unwatch()
```

## Health

```vim
:checkhealth ahdr
```

## License

MIT
