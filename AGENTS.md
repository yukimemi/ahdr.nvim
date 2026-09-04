# AGENTS.md

Guidance for AI agents (Claude / Codex / Gemini) working in this
repo. The yukimemi/* shared conventions live in the
`<!-- kata:agents:* -->` blocks below, sourced from
`yukimemi/pj-base` / `pj-nvim` via `kata apply` — see those for git
workflow, PR review cycle, test / lint commands, and renri's worktree
usage.

The sections above the marker blocks are ahdr-specific and
consumer-owned: edit them freely; `kata apply` won't touch them.

## コンセプト

- **denops 廃止・pure Lua / Neovim 専用**: [`ahdr.vim`](https://github.com/yukimemi/ahdr.vim) (denops/Deno) の後継。現在のバッファから「header を前置 + 名前を変形」した派生ファイルを生成する。主用途は PowerShell/cmd ポリグロット launcher (`foo.ps1` → cmd が PowerShell を起動する `foo.cmd`)。
- **TOML 廃止 → setup() テーブル**: 旧版は `~/.config/ahdr/ahdr.toml` を読んで bundled config とマージしていた。新版は generators を Lua テーブルで持つ。`config.lua` に bundled defaults (ps1/javascript/dosbatch)、`setup({ generators = {...} })` で追加。
- **Convention over Configuration**: `plugin/ahdr.lua` が `:Ahdr` / `:AhdrWatch` / `:AhdrUnwatch` を eager 登録。`setup()` は generators 追加のためだけ。
- **補完追加**: `:Ahdr <Tab>` で現在 filetype の generator 名を補完 (denops 版に無かった UX)。
- **Notify ゲート契約**: background は `log.at` 系、ユーザ起点コマンドは `log.echo`。watch (保存毎) の成功通知は `quiet=true` で `log.info` (notify ゲート) に落とす。

## テストが mini.test である理由

一般的なテスト / lint コマンドは下の `kata:agents:nvim:*` ブロックにある。ここに
書くのは **この選択の背景** だけ。

`nvim -u NONE -l scripts/run_tests.lua` で走らせるため、子プロセスがユーザの
`~/.config/nvim/init.lua` を読まない。plenary の `PlenaryBustedFile` は子 nvim を
spawn する際に `-u` を引き継がないので、ユーザ環境によっては作業ツリーではなく
rtp 上の**古いコピー**を読んでテストが通ってしまう事故が起きる。

補足: 以前このファイルには「plenary は 2026-06-30 アーカイブ」と書かれていたが、
これは誤り。plenary は現在もアーカイブされていない (`archived=false`、最終 push
2026-04-10)。採用理由は上記の実行モデルであって、上流の生死ではない。

spec ファイル名は mini.test 既定の **`test_*.lua`** (plenary の `*_spec.lua` ではない)。

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
deps/                       — CI が clone するテスト依存 (mini.nvim)。gitignore 済み
.github/workflows/ci.yml    — kata-managed (yukimemi/pj-nvim)。3 OS × stable/nightly + stylua lint
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

<!-- kata:agents:base:begin -->
## Shared conventions

This file is the agent-agnostic source of truth (per the
[agents.md](https://agents.md) convention). The matching
`CLAUDE.md` and `GEMINI.md` files are thin shims that point back
here so each tool's auto-load behaviour still finds something.
**Edit AGENTS.md, not the shims.**

### Git workflow

- **No direct push to `main`.** Open a PR.
  - Exception: trivial typo / whitespace / docs wording fixes.
- Branch names: `feat/...`, `fix/...`, `chore/...`.
- **PR titles + bodies in English. Commit messages in English.**
- **Releases are PR-driven and tagging is automatic** — in repos that
  ship a release pipeline. Bump the version in the project's own
  manifest in a `chore/release-vX.Y.Z` PR; on merge to `main` the
  language layer's `auto-tag.yml` detects the bump, pushes the
  `vX.Y.Z` tag, and that tag is what fires `release.yml`. **Do not run
  `git tag` by hand** — the bot tag will collide and the manual push
  fails. The specifics belong to the layers shipping those two
  workflows, which are not the same layer: `kata:agents:rust:*` for
  which file holds the version and for `auto-tag.yml`,
  `kata:agents:rust-{cli,lib}:*` for what `release.yml` builds and
  publishes. A repo with no `auto-tag.yml` has no release pipeline at
  all: nothing tags, and the version field in its manifest may well
  be decoration.

### Pre-merge review

Review happens **before the pull request, on the operator's machine**,
via [magi](https://github.com/yukimemi/magi). This layer no longer
ships PR-side review bots: `claude-review.yml` and `claude.yml` were
removed from it. Their scope was
human-authored PRs — their own job-level `if:` already excluded
`chore/release-*`, `kata-apply/auto`, `apm-bump/auto` and
Renovate / Dependabot — which is exactly the set magi reviews, so
keeping them meant reviewing the same diff twice, a
`CLAUDE_CODE_OAUTH_TOKEN` secret per repository, Actions minutes on
private repos, and one trap that silently cost reviews: a PR editing
either workflow was skipped by `claude-code-action`'s
workflow-validation check and merged with a green check and no
review attached.

**"Removed" is a statement about this template layer, not about
every repo's current state.** Dropping a `[[file]]` entry stops kata
from managing the rendered file — it does not delete it. A repo that
had these workflows before this change keeps `claude-review.yml` /
`claude.yml` (and the `CLAUDE_CODE_OAUTH_TOKEN` secret) under
`.github/workflows/` until someone deletes them by hand, and until
then they still fire on every human-authored PR. Check
`.github/workflows/` before treating a PR as unreviewed-except-magi:
if either file is still there, its comments are a real review, not
noise to ignore.

- **`magi review <branch>`** runs only the review + verification +
  gate half of magi's graph: nothing competes, no implementation, no
  judging, no vote. That is the mode for hand-written work.
  `magi run "<task>"` is the full competition, for work handed over
  whole. Both end at the same gate.
- What the loop actually does: each reviewer gets its **own detached
  worktree pinned at the commit under review** (no reviewer can
  perturb the tree, and the fixer never races one); `verify.e2e` runs
  in the branch's worktree and its output is fed to the fixer;
  finding ids (`R2-1-3`) are assigned by magi, not by the agent, so
  the fixer's adoption report can be matched against them; the loop
  is bounded by `review_rounds`; `verify.gate` must exit 0 before any
  merge is attempted.
- **`magi.toml` is repo-owned, not kata-managed.** Point
  `verify.gate` at the exact command CI runs, so a local pass means a
  green PR, and point `verify.e2e` at the invocation that actually
  covers the repo — feature flags included. A gate that differs from
  CI turns a clean magi run into a red PR, which is the one failure
  this arrangement cannot absorb.
- **If you did not run magi, the change was not reviewed, and nothing
  will tell you.** Do not open a PR for a hand-written change before
  `magi review` comes back clean; if you must, say so in the PR body
  and say why. What does *not* count as a substitute: a green CI run
  (it compiles and tests, it does not review), and CodeRabbit's
  silence.
- **CodeRabbit stays installed and is not part of the gate.** It does
  not auto-review repositories under 10 stars — the common case here —
  so treat it as absent unless it posts. When it does post, its
  findings are a real review: address them, reply **in the inline
  thread** with an `@coderabbitai` mention (the review-comment
  *replies* endpoint,
  `gh api repos/<owner>/<repo>/pulls/<N>/comments/<id>/replies -f body=…`),
  and reply even when declining — say why, because a silent skip
  reads as overlooked. A "review limit reached" quota notice carries
  no findings and counts as quiet; re-trigger with
  `@coderabbitai review` when the quota refills if you want a real
  pass.
- **Read the report, not the exit status.** A reviewer seat that
  times out is logged as `WARN agent timed out seat=review-2` and
  then summarised as "raised 0 finding(s)" — indistinguishable from a
  genuinely clean pass in both the summary and `magi stats`. Check
  for timeouts before believing a clean round: a round where half the
  panel never answered is not a clean round.
- **Review artifacts stay local.** magi comments on a pull request
  only when it *stops* landing one. Findings, the fixer's adoption
  report and reviewer precision live in the run directory
  (`magi show`, `magi stats`). When the PR needs a record — a
  non-obvious fix, a finding declined with an argument — paste that
  part into the PR body or a comment yourself.
- With `merge = "pr"`, magi opens the pull request and keeps going:
  watches the checks, reads the review comments (human and bot), runs
  a bounded fix round when either is unhappy, pushes, and asks before
  merging. `land_approval` is on by default and **silence is a
  hold** — nothing merges unanswered. `magi answer` (or the web UI)
  is where it asks. Out of rounds leaves the PR open with a comment
  saying what still fails; `checks: unknown` never merges.
- **Merge gate**: magi's gate green — or CI green for a change magi
  never touched — **and** every review that did post resolved (a
  leftover `claude-review.yml`, CodeRabbit, a human) **and** the
  owner's explicit approval. The irreversible step stays a human
  decision.
- **No review-monitoring poll loop for bots this layer no longer
  ships.** The old loop existed to wait on them. Where a repo still
  has `claude-review.yml` (see above) the old cadence still applies
  until it is deleted; otherwise, after opening a PR wait for CI and
  report the wait state to the owner. When magi is landing the PR
  (`land = true`), magi does the watching.
- Bot-authored PRs (Renovate / Dependabot) need no review pass at
  all: CI green + owner approval.
- **Version-bump-only PRs** — a single `chore/release-vX.Y.Z` branch
  whose entire diff is `[workspace.package].version` /
  `[package].version` plus the matching inter-crate refs and the
  lockfile — likewise. There is nothing in a version bump for a
  reviewer to find, and the release pipeline downstream of merge
  (auto-tag → `release.yml`) is time-sensitive.

### Worktree workflow

> **Before your FIRST edit to any file, run `renri add` — NEVER edit the
> main checkout.** Read-only inspection (Read / Grep / Glob) stays on the
> main checkout; the instant you intend to *change* a file, you must
> already be in a worktree. The trap that keeps catching agents: diving
> into a fix the moment the diagnosis lands and editing in place. A
> concurrent agent shares the main checkout — your in-place edits will
> clobber theirs or be clobbered, and in a jj-colocated repo a stray
> working-copy commit entangles unrelated WIP into your branch. If you
> slip and edit in the main checkout, capture the diff first (jj already
> snapshotted it into the working-copy commit, so `jj diff > patch`; for
> git, `git stash` or save a patch — if you got as far as committing on a
> branch, just push it). Then reset the main checkout to pristine main
> (`jj new main@origin`, or `git switch -`), `renri add` a worktree, and
> re-apply the captured diff there.

Use [`renri`](https://github.com/yukimemi/renri) for any
commit-bound change. From the main checkout:

```sh
renri add <branch-name> --from main@origin            # create a worktree (jj-first), off latest upstream main
renri --vcs git add <branch-name> --from origin/main  # force a git worktree, off latest upstream main
renri remove <branch-name> -y --non-interactive  # cleanup after merge (agent-safe; see note)
renri prune                        # GC stale worktrees
```

Read-only inspection can stay on the main checkout.

**Always pass `--from <upstream main>`** (`main@origin` for jj,
`origin/main` for git). Without it, `renri add` forks off the *cwd
worktree's current HEAD* — in a long-lived main checkout that often
lags upstream, so the PR later shows up CONFLICTING against a `main`
that had already moved (e.g. a refactor merged upstream before the
branch was cut), forcing a manual re-port of the whole change.
`renri add` does fetch first, but fetching only updates `main@origin`
— it never moves the checkout's HEAD, so an explicit `--from` is what
guarantees a fresh base.

**Agents / non-interactive shells:** `renri remove` prints a details
panel and waits for a confirmation prompt — without `-y` it **hangs**,
and `--non-interactive` *alone* errors asking for `-y`. Always pass
`-y`, and add `--non-interactive` so a mistyped/omitted name fails
instead of opening a fuzzy picker (the same picker-fallback applies to
`remove` / `cd` / `exec` with no name). Use `-f`/`--force` to remove a
worktree that still has uncommitted changes or conflicts. To sweep
every merged-PR worktree in one shot: `renri remove --merged -y`.

### kata-managed sections

Several files in this repo are managed by `kata apply` from the
[`yukimemi/pj-presets`](https://github.com/yukimemi/pj-presets)
templates — the bytes between `<!-- kata:*:begin -->` and
`<!-- kata:*:end -->` markers, plus the overwrite-always files
listed in `.kata/applied.toml`. **Editing those bytes locally
won't survive the next `kata apply`** — push the change to the
upstream template repo (`yukimemi/pj-base` / `yukimemi/pj-rust` /
…) instead.

The marker scopes are layered, one per applied layer:
`kata:agents:base:*` is this section, and each layer adds its own
(`kata:agents:rust:*`, `kata:agents:rust-cli:*`,
`kata:agents:pnpm:*`, `kata:agents:firebase:*`, …). Which ones apply
*here* is a grep away: `<!-- kata:` in this file.

### This project's own conventions

Everything a layer ships is generic by construction: it describes the
stack the template assumed, not what this repo grew into. **Bytes
outside every marker pair are yours and survive `kata apply`** — so
project-specific conventions belong in a section of their own, outside
the markers (conventionally at the end of the file; if a later layer
appends its block below yours, no matter — kata only ever rewrites
between its own markers). Same mechanism as the `.gitignore` /
`.gitattributes` blocks.

Write those conventions down there rather than leaving them in one
agent's head, in commit archaeology, or in a README the agent will not
read. What earns a line:

- **Any layer default that does not hold here.** A layer states its
  assumption flatly ("Hosting is the primary target", "these rules are
  a placeholder to replace"). When the project has diverged, say so and
  say why — the layer's text keeps asserting the opposite on every
  apply, and an agent that only reads the blocks will act on it.
- **Facts duplicated across files with no compiler in between** — an
  address or a path that appears in code *and* in a rules/config file
  that cannot import it, a timeout that has to stay inside another
  timeout. List every copy, so the next edit finds them all.
- **kata-shipped files this project deleted on purpose**, together with
  the `once_applied = true` line in `.kata/applied.toml` that keeps
  them deleted. Otherwise someone helpfully restores one.
- **Shapes the runtime forces but no tool checks** — an export form a
  platform requires, import specifiers that must (or must not) carry a
  file extension, a directory whose contents are reachable by URL.
- **Invariants that money or access rest on**, naming the file and line
  that actually enforces them.
- **Which language the code speaks versus what a user reads**, when the
  two differ.

A repo whose `AGENTS.md` is nothing but kata blocks is a repo where
every agent re-derives all of that from scratch — and gets the layer
defaults wrong the same way each time.
<!-- kata:agents:base:end -->
<!-- kata:agents:nvim:begin -->
### Neovim plugin workflow

This repo follows the shared Neovim plugin conventions. The
language-agnostic conventions block above (`kata:agents:base:*`)
covers git workflow, PR review cycle, and worktree usage.

### Test / lint

There is no build step — Lua is interpreted, so the whole gate is
"tests pass and stylua is clean":

```sh
stylua --check .                    # format gate (what CI runs)
stylua .                            # apply formatting
```

Tests run through Neovim itself, one file per invocation. Which
framework is in play depends on `nvim.test_runner` in
`.kata/vars.toml`:

```sh
# test_runner = "mini"  (deps/mini.nvim)
nvim -u NONE -l scripts/run_tests.lua tests/<plugin>/test_foo.lua

# test_runner = "plenary"  (deps/plenary.nvim)
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/<plugin>/foo_spec.lua"
```

**Run one file per `nvim` invocation, and match CI's discovery
pattern.** CI enumerates specs with `find tests -type f -name …` and
loops in the shell rather than letting the framework walk the
directory: `PlenaryBustedDirectory` spawns `pwsh` on Windows runners
to enumerate files, and pwsh's ~5s startup blows plenary's internal
timeout. A file-at-a-time loop behaves identically on all three OSes
and keeps a crash in one spec from taking the rest of the suite with
it.

### Test dependencies live in `deps/`

CI clones the framework into `deps/mini.nvim` or `deps/plenary.nvim`.
Keep `deps/` out of the repo (it is in `.gitignore`) and out of
formatting (`.styluaignore`). If your `minimal_init.lua` hardcodes a
different path, fix the init file rather than the workflow — the
workflow is kata-managed and a local edit will be reverted.

### Neovim version support

CI runs the full matrix: `ubuntu` / `macos` / `windows` x `stable` /
`nightly`. A nightly-only failure is still a failure — either guard
the API behind a version check or fix the call. Don't reach for a
newer API without confirming it exists on `stable`; `vim.fn.has()` or
a `pcall` around the lookup is the usual guard.

### Lint / format policy

`.stylua.toml` is kata-managed (sourced from `yukimemi/pj-nvim`).
Edits to it in this repo won't survive the next `kata apply`; if a
setting is wrong, push the fix to `yukimemi/pj-nvim` so every Neovim
plugin using these templates picks it up. `.styluaignore` is
consumer-owned after the first apply — extend it freely.

### CI workflow

`.github/workflows/ci.yml` is kata-managed. The source lives in
`yukimemi/pj-nvim/.github/workflows/ci.yml.tera` (the `.tera` suffix
keeps GitHub Actions from running the source inside pj-nvim itself
and opts the file into kata's Tera rendering). Action versions are
pinned in `.kata/vars.toml` and bumped by Renovate, so don't edit
them inline in the workflow — the bump would be clobbered on the
next apply.

### Auto-merge preconditions (one-time, per repository)

Merging is GitHub's native auto-merge, armed by Renovate
(`platformAutomerge`) and by pj-base's `kata-apply` / `apm-bump`
workflows via `gh pr merge --auto`. Three repo-side settings are
required, and none of them can ship from a template — a freshly
created plugin has to be onboarded by hand, exactly like the pj-rust
and pj-denops lines:

* **`KATA_APPLY_TOKEN` secret** — a PAT with write access to the repo.
  `kata-apply.yml` / `apm-bump.yml` check out and push with it rather
  than `GITHUB_TOKEN`, whose pushes never trigger CI. Without it the
  job dies at checkout with `Input required and not supplied: token`.
* **`allow_auto_merge` enabled** on the repository.
* **Branch protection on `main`** requiring `test (ubuntu-latest /
  nvim stable)` and `stylua`. GitHub only arms auto-merge on a pull
  request that is currently blocked; with no required check the PR is
  immediately mergeable and the request is rejected with
  `Pull request is in clean status` or `Branch does not have required
  protected branch rules`.

Only the ubuntu legs are required on purpose. The macOS / Windows legs
and both nightly legs still run and still have to be read, but a flaky
runner or an upstream nightly regression must not wedge every
dependency PR.

```sh
gh secret set KATA_APPLY_TOKEN --repo yukimemi/<plugin>
gh repo edit yukimemi/<plugin> --enable-auto-merge
gh api -X PUT repos/yukimemi/<plugin>/branches/main/protection --input - <<'JSON'
{
  "required_status_checks": {
    "strict": false,
    "contexts": ["test (ubuntu-latest / nvim stable)", "stylua"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null
}
JSON
```

Skipping these is silent: the plugin looks fine, but `kata-apply`
fails every night and no template update ever reaches the repo.
<!-- kata:agents:nvim:end -->
