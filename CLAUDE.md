# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## コンセプト

- **denops 廃止・pure Lua / Neovim 専用**: [`ahdr.vim`](https://github.com/yukimemi/ahdr.vim) (denops/Deno) の後継。現在のバッファから「header を前置 + 名前を変形」した派生ファイルを生成する。主用途は PowerShell/cmd ポリグロット launcher (`foo.ps1` → cmd が PowerShell を起動する `foo.cmd`)。
- **TOML 廃止 → setup() テーブル**: 旧版は `~/.config/ahdr/ahdr.toml` を読んで bundled config とマージしていた。新版は generators を Lua テーブルで持つ。`config.lua` に bundled defaults (ps1/javascript/dosbatch)、`setup({ generators = {...} })` で追加。
- **Convention over Configuration**: `plugin/ahdr.lua` が `:Ahdr` / `:AhdrWatch` / `:AhdrUnwatch` を eager 登録。`setup()` は generators 追加のためだけ。
- **補完追加**: `:Ahdr <Tab>` で現在 filetype の generator 名を補完 (denops 版に無かった UX)。
- **Notify ゲート契約**: background は `log.at` 系、ユーザ起点コマンドは `log.echo`。watch (保存毎) の成功通知は `quiet=true` で `log.info` (notify ゲート) に落とす。

## Git ワークフロー

- **main 直 push しない。** フィーチャーブランチ + PR。**PR / commit は英語** (Conventional Commits)。
- 全 PR で Gemini / CodeRabbit レビュー。指摘対処 (fix push → @-mention reply)、actionable 消失 + オーナー (@yukimemi) 承認まで merge しない。bot-authored PR は除外。

## Development Commands

テストは **mini.test** (plenary は 2026-06-30 アーカイブ)。`scripts/run_tests.lua` (headless, cquit)。

```bash
git clone --depth 1 https://github.com/echasnovski/mini.nvim deps/mini.nvim
# または既存 clone を $MINI_NVIM で再利用

set -e
status=0
for f in tests/ahdr/test_*.lua; do
  nvim -u NONE -l scripts/run_tests.lua "$f" || status=$?
done
exit $status
```

- `nvim -u NONE -l` で user config を読まずに実行。spec 名は **`test_*.lua`**。

## アーキテクチャ

### ファイル構成

```text
plugin/ahdr.lua             — :Ahdr* を eager 登録
lua/ahdr/
  init.lua                  — setup() + Lua API (generate/watch/unwatch)
  config.lua                — bundled defaults (ps1/js/dosbatch) + generators の ft 別 concat マージ (ユーザ優先)
  log.lua                   — notify ゲート + echo
  ahdr.lua                  — コア generate(): generator 検索 → outpath 計算 → header+本文 → vim.uv 非同期 write
  watch.lua                 — buffer-local BufWritePost で再生成 (watch/unwatch)
  command.lua               — :Ahdr / :AhdrWatch / :AhdrUnwatch + 補完
  health.lua                — :checkhealth ahdr
scripts/run_tests.lua
tests/ahdr/test_*.lua
.github/workflows/ci.yml    — test (ubuntu/macos/windows × stable/nightly) + stylua lint
```

### 生成のコア (`ahdr.lua`)

- generator は `{ name, ext, header, prefix?, suffix?, dst? }`。`for_filetype(ft)` から `name` 一致を探す (ユーザ generator が先頭なので override)。
- outpath = `<resolve_dst>/<prefix><stem><suffix><ext>`。`stem` は `fnamemodify(src, ":t:r")`。`resolve_dst` は dst が絶対ならそのまま、相対なら source dir 基準で `vim.fs.normalize` (`../cmd` を解決)。
- 本文 = `header .. "\n" .. table.concat(lines, "\n")`。`fileformat == "dos"` なら `gsub("\n", "\r\n")` で CRLF。
- `mkdir` は同期 (メインスレッド) で先に、write は `vim.uv` 非同期 (watch の保存をブロックしない)。完了通知は `vim.schedule`。

### 設定マージ (`config.lua`)

`generators` は ft→list の map。tbl_deep_extend は list を index マージしてしまうので、generators だけ別処理: 各 ft で **ユーザ list を先頭、bundled defaults を後ろ**に concat。検索は先頭一致なのでユーザが同名 override 可能。

## 設計原則

- **保存を止めない.** write は非同期。失敗は `log.echo`(ERROR)。
- **Notify ゲート契約.** background `log.at` / ユーザ起点 `log.echo` / watch 成功は `quiet`→`log.info`。
- **テスト先行.** generate の挙動 (header+本文、prefix/suffix/ext、dst 解決、dos CRLF) は `tests/ahdr/test_*.lua` で守る。async write は「ファイル出現」でなく **完成コンテンツ** を `vim.wait` でポーリング (fs_open は fs_write に先行)。
- **Windows 特性.** CI に `windows-latest`。`resolve_dst` の絶対判定 (`%a:/`)、`nvim_buf_get_name` 正規化に注意。テストは `nvim -u NONE -l` で全 OS 共通。

## 移植元との差分 (denops 版からの設計変更)

- TOML ファイル設定 → `setup()` の Lua テーブル。`g:ahdr_*` グローバル廃止、`debug` → `log_level` + notify ゲート。
- `:DenopsAhdr {name}` → `:Ahdr {name}` (+ filetype 別補完)。
- ハードコードの DenopsAhdrDebug/PwshDebug (保存毎再生成) → 汎用 `:AhdrWatch {name}` / `:AhdrUnwatch`。
- 別プロセス async write → in-process `vim.uv` async write。
