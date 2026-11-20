# Neovim / LazyVim

This configuration uses [LazyVim](https://www.lazyvim.org/) with lazy.nvim.
`setup-windows.ps1` links `%LOCALAPPDATA%\nvim` to this directory, so edits
apply to the normal `nvim` command.

## Orcas development

Open the checkout and then a source file:

```powershell
Set-Location C:\Repos\orcasql-breadth
nvim .
```

The .NET extra in `lazyvim.json` supplies .NET tooling.
`lua\plugins\dotnet.lua` uses the modern Roslyn C# language server for
completion, diagnostics, hover documentation, and navigation into source
and NuGet metadata. OmniSharp is disabled for C#.

The configuration uses `roslyn-language-server` when it is on PATH;
otherwise it discovers the server bundled with the newest installed
VS Code C# extension. No extension version or absolute path is hard-coded.

The nearest ancestor `.sln` or `.slnx` takes priority. For Orcas projects
without an ancestor solution, the configuration falls back to
`src\OrcasBreadthRP\ResourceProvider\OrcasBreadthRP.sln`. This also works
for shared projects in the `MeruCommon` submodule and for other checkout
locations. Projects outside that solution and its references should be
opened under their own solution.

On Windows, Roslyn uses its native file watcher so source changes made
outside Neovim are reflected in diagnostics and navigation. See
`..\troubleshooting\nvim-csharp-stale-external-changes.md` if Neovim reports
a missing member that exists in the current checkout and builds successfully.

Treesitter provides highlighting for C#, SQL, Rust, PowerShell, XML,
JSON, YAML, Python, and shell scripts. MSBuild project/property files
and `.resx` files are recognized as XML. SQL, Rust, and PowerShell have
syntax highlighting here, not language-server navigation.

## Editing keys

The leader key is Space.

| Key | Action |
| --- | --- |
| `gd` | Go to definition, including C# metadata |
| `gr` | Find references |
| `gI` | Go to implementation |
| `K` | Hover documentation |
| `<leader>cr` | Rename symbol |
| `<leader>ca` | Code actions |
| `<leader>cd` | Show line diagnostics |
| `<leader>cl` | Inspect attached language servers |
| `<leader>ff` | Find files |
| `<leader>fya` | Copy the absolute file path, with selected lines |
| `<leader>fyr` | Copy the Git-relative file path, with selected lines |
| `<leader>fyc` | Copy the cwd-relative file path, with selected lines |
| `<leader>fyn` | Copy the file name, with selected lines |
| `<leader>gu` | Preview unstaged Git changes, including untracked files |
| `<leader>gR` | List Azure DevOps pull requests |
| `<leader>sg` | Search text |
| `Ctrl+o` | Return after a navigation jump |

After `<leader>fy`, press `a`, `r`, `c`, or `n` to copy immediately without
opening a format picker. Git-relative paths use the file's Git
repository/worktree root, not its language-server project root.
Working-directory-relative paths use Neovim's current window/tab directory and
include `..` when the file is outside that directory.

With a Visual selection, each format includes `:42` for one selected line or
`:42-48` for a line range. Characterwise, linewise, and blockwise selections
are supported; backward selections produce an ascending range. In normal
mode, no line suffix is added.

Git-relative paths are unavailable outside Git repositories;
working-directory-relative paths are unavailable across Windows drives or
network shares. An unavailable format shows a warning without changing the
clipboard.

## Git change previews

`<leader>gu` opens an unstaged-only diff picker for the current Git repository,
including untracked files. Tracked changes show diff hunks; untracked files
preview their contents. Press Enter to open the selected file or hunk.

In the diff picker, `Alt+s` cycles all changes, unstaged changes, and staged
changes. `<leader>gd` still opens all staged and unstaged changes.
`lua\plugins\git-diff-filter.lua` provides these controls, matching the WSL
configuration. `<leader>u` remains the UI-toggle menu.

With focus in the picker's search box, Tab stages an unstaged hunk or
unstages a staged hunk. For an untracked file, it stages the entire file.
Patch bytes retain their original LF/CRLF line endings; previews normalize
line endings for display only. See
`..\troubleshooting\nvim-git-hunk-staging-crlf.md` if Git rejects a hunk.

## Azure DevOps PR reviews

`lua\plugins\ado-pr.lua` adds
[ado-pr.nvim](https://github.com/jinyeow/ado-pr.nvim), with fzf-lua for its
PR picker and Diffview Plus for the diff panes. Existing Snacks file/search
pickers are unchanged. The ADO plugin is experimental and pinned to a
specific revision; its three plugin versions are recorded in `lazy-lock.json`.

Restart Neovim after installing the configuration. From an ADO checkout,
press `<leader>gR` (Space, g, uppercase R) or run `:AdoPr`. Organization,
project, and repository are detected from the Git remotes, including legacy
`visualstudio.com/DefaultCollection` URLs. Use `:AdoPrShowScope` to inspect
the detected scope; no work-specific URL is stored in this configuration.

The PR picker fetches every page of **active** PRs, then searches their IDs,
titles, and author names locally. It refreshes the list each time it opens;
completed and abandoned PRs are excluded. Fetching all pages can take longer
in a large repository. `lua\config\ado-pr-list.lua` supplies pagination using
the plugin's existing scope resolution and safe Azure CLI transport.
See `..\troubleshooting\nvim-pr-picker-missing-older-prs.md`.

Azure CLI must be on PATH, with its `azure-devops` extension installed and
an authenticated session from `az login`. The plugin reuses that session;
it does not store a PAT. It supports the Windows `az.cmd` entry point.

| Command/key | Action |
| --- | --- |
| `:AdoPrReview 12345` | Check out a PR and open its diff |
| `<leader>gC` / `:AdoPrComments` | Search all PR comments with preview |
| `]T` / `[T` | Next/previous PR comment across files |
| `<leader>gv` | Toggle inline / side-by-side diff |
| `zl` / `zh`, `zL` / `zH` | Scroll columns / half-window, including deletions |
| `<leader>ghw` | Toggle the current hunk's reviewed state |
| `]r` / `[r` | Next/previous unreviewed hunk, including across files |
| `w` in the file list | Toggle all hunks in a file reviewed/unreviewed |
| `H` in the file list | Hide/show reviewed files |
| `:AdoPrComment` | Post a comment at the diff cursor or Visual line range |
| `:AdoPrIterations` | Review one push at a time |
| `F8` | Toggle the comment-thread pane |
| `]t` / `[t` | Next/previous comment thread in the current file |
| `F6` / `F7` | Show/cycle a thread or pick an overlapping thread |
| `:AdoPrVote 12345 approve` | Submit an approval vote |
| `:DiffviewClose` | Close the diff tab |

PR reviews and ordinary Diffview diffs open in the inline/unified layout.
Press `<leader>gv` (Space, g, v) in a diff pane or the file list to toggle
between inline and side-by-side for the current view's regular files.
The shortcut is local to Diffview; merge-conflict layouts are unchanged.

Diffview keeps unchanged regions expanded, so the entire file is available
in both layouts. Opening a review focuses the diff
pane at the first change. `Tab` / `Shift+Tab` switch files; newly opened files
start at their first change, while revisited files retain their cursor position.
Use `]c` / `[c` for next/previous changes and `<leader>e` to focus the file list.
If you manually collapse context, `zR` expands all folds in the focused pane.
See `..\troubleshooting\nvim-pr-diff-folded-context.md`.

Inline deleted rows scroll horizontally with the rest of the diff. Focus the
diff pane and use `zL` / `zH` for half-window scrolling, or `20zl` / `20zh` for
20 columns. `lua\config\diffview-inline.lua` enables scrollable virtual rows
and window-local `nowrap` / `virtualedit=all`, allowing the viewport to move
beyond a short new line when its deleted predecessor was longer. Those
options are restored when the inline layout detaches; ordinary buffers and
side-by-side diffs retain their usual behavior. The virtual space is not file
content, although typing there in an editable working-tree diff can insert
padding. `Space g v` remains available to read the old text in a real buffer.
See `..\troubleshooting\nvim-pr-inline-deleted-line-scrolling.md`.

Opening a PR performs a checkout. In a plain clone it requires a clean tree
and switches branches in place. When the repository already has multiple
worktrees, the plugin creates/reuses a detached `prreview` worktree beside
the invoking worktree and moves Neovim's working directory there. Submodules
are not initialized automatically. Save your work and check the working
directory before editing or building after a review.

Comment and vote commands write to ADO immediately, not to a pending review
draft. Use the ADO web page for build gates, policies, and reviewer management.

The PR-list regression is `tests\ado-pr-list.lua`. Set
`NVIM_PR_LIST_TEST_DIR` to a temporary directory and run
`nvim --headless -i NONE --cmd "lua dofile([[<absolute test script path>]])"`.
It exercises the native picker with simulated Azure CLI pages and does not
perform real PR checkouts or ADO writes.

### PR-wide comments

Press `<leader>gC` (Space, g, uppercase C) or run `:AdoPrComments`.
The searchable Snacks list includes every non-deleted human comment and
reply, including resolved threads, file-level discussions, and PR-level
comments. Each row shows its path/line, side, status, author, and text.
The preview displays the complete comment. System activity is excluded.
Opening the list refreshes it from ADO.

Select a row with Enter to focus its exact file and line and display its
comment. `]T` / `[T` step through the same list, wrapping across files and
replies; these keys work in diff panes, the file list, and comment snapshots.
The commands `:AdoPrNextComment` / `:AdoPrPrevComment` do the same.
Lowercase `]t` / `[t` retain the plugin's current-file thread navigation.

Old-side comments switch inline diffs to side-by-side so the cursor can land
on the actual old line rather than a virtual deletion marker. `<leader>gv`
returns to inline mode. Comments on unchanged files open a read-only commit
snapshot; `q` returns to the review. For outdated or missing anchors, the
navigator uses ADO's original tracked position and revision when available.
Unavailable positions are reported rather than guessed or clamped.
PR-level comments display their text without inventing a file anchor.

`lua\config\ado-comments.lua` implements the list and navigation without
changing the installed plugin. It uses the current iteration's tracked
positions when browsing iterations and refuses stale selections after a
PR/revision change. Navigation does not submit comments, votes, or status
changes. See `..\troubleshooting\nvim-pr-comment-navigation.md`.
The headless regression is `tests\ado-comments.lua`; set
`NVIM_COMMENT_TEST_DIR` to a fresh temporary directory and run it with
`nvim --headless -i NONE --cmd "lua dofile([[<absolute test script path>]])"`.
It exercises the real picker/diff UI against synthetic Git commits with
mocked ADO read responses and no ADO writes.

### Hunk review progress

`lua\config\diffview-review.lua` adds local review tracking for Git
commit-to-commit diffs, including ADO PRs. Each hunk shows `[ ]` or `[x]`;
press `<leader>ghw` (Space, g, h, w) on a changed line to toggle it. The file
is marked reviewed automatically once every text hunk is reviewed.
Unreviewing one hunk removes the file mark. In the file list, `w` marks or
unmarks the entire file, including all its hunks.

`]r` / `[r` skip reviewed hunks, cross file boundaries, and wrap around the
diff. They also work from the file list and with reviewed files hidden by `H`.
Files without text hunks, such as binary or mode-only changes, are skipped;
review and mark those at file level with `w`. Linematch sub-hunks sharing
a cursor anchor are reviewed together so no change is unreachable.

Progress is saved immediately under
`stdpath("state")\diffview-hunk-review`, outside the repository. It survives
closing the diff and restarting Neovim. It is scoped to the checkout, exact
resolved old/new commits, and diff options: a different push, iteration, or
base starts fresh. Reopening the same comparison restores its progress.
Both inline and side-by-side layouts share the same marks.

Only completion metadata is saved, not source text. These marks do not
submit comments, votes, or review status to ADO. They use Diffview's file
selections, which also apply to its native bulk file operations.
Working-tree/index diffs and merge conflicts do not use saved hunk reviews.

The headless regression in `tests\diffview-review.lua` uses an isolated Git
fixture and no remote writes. Set `NVIM_REVIEW_TEST_DIR` to a fresh temporary
directory and run it in two separate Neovim processes with
`NVIM_REVIEW_TEST_PHASE=write`, then `NVIM_REVIEW_TEST_PHASE=reload`:
`nvim --headless -i NONE --cmd "lua dofile([[<absolute test script path>]])"`.
The optional `guard` phase checks corrupted state and mutable comparisons.

## UI motion

Snacks UI animations are disabled, including animated scrolling,
indent-guide transitions, and dimming transitions. The cursor does not
blink, but keeps its mode-dependent shape. LSP progress messages remain
visible as text without an animated spinner.

`lua\config\options.lua` controls animations and cursor blinking;
`lua\plugins\animations.lua` controls LSP progress formatting. These
settings affect Neovim only, not Windows Terminal or WezTerm.

## Diagnostic display

Only errors and warnings appear as inline diagnostic text or squiggly
underlines, across all languages. Informational/style suggestions remain
available through `<leader>cd` (line diagnostics), with signs unchanged.
C# parameter/type inlay hints remain enabled.

Markdownlint formatting diagnostics (such as line length and table alignment)
are on demand: `<leader>cd` shows them without inline text or underlines.
Collection, gutter signs, and other Markdown diagnostic sources remain enabled.
Markdown spell-check defaults to off; `<leader>us` toggles it when needed.
Wrapping and Markdown rendering are unchanged.

`lua\plugins\diagnostics.lua` controls this display filter; it does not
disable analyzers or remove diagnostics. See
`..\troubleshooting\nvim-inline-diagnostic-noise.md` for details, and
`..\troubleshooting\nvim-markdown-diagnostic-noise.md` for Markdown.

## Mixed line endings

Files that already mix CRLF and LF keep Neovim's detected LF buffer
representation, even when EditorConfig requests CRLF. This prevents doubled
carriage returns in Roslyn and GitSigns without normalizing the source file.
A warning appears once per affected file per session; other EditorConfig
properties and newline rules for pure-LF, pure-CRLF, and new files still apply.
Real errors, including StyleCop rules configured as errors, remain visible.

`lua\config\line-endings.lua` installs this guard during early startup.
See `..\troubleshooting\nvim-mixed-line-endings.md` for symptoms and recovery.
The regression `tests\mixed-line-endings.lua` checks real EditorConfig,
GitSigns/Git agreement, LSP document bytes, and diagnostic visibility.
Set `NVIM_EOL_TEST_DIR` to a fresh temporary directory and run
`nvim --headless -i NONE --cmd "lua dofile([[<absolute test script path>]])"`.

## LazyGit

Open LazyGit with `<leader>gg`. On Windows, both `o` and `e` open the selected
file in the current Neovim window and close the LazyGit terminal. Editing a
diff opens the file at the selected line; no separate editor tab or Windows
application chooser is opened.

`lua\plugins\snacks-lazygit.lua` configures only LazyGit launched through
Neovim's Snacks integration. Standalone LazyGit keeps its normal settings.
See `..\troubleshooting\nvim-lazygit-opens-external-app.md` for details.

## Prerequisites and troubleshooting

Install the dependencies supplied by `setup-windows.ps1`, including
Neovim, a C compiler, and tree-sitter-cli. Treesitter installs missing
parsers on startup. Install the VS Code C# extension or provide
`roslyn-language-server` on PATH.

If this same checkout builds but Neovim reports missing types such as
`ILogger`, `JObject`, or `NpgsqlConnection`, run `:lsp restart roslyn_ls`
and wait for project initialization. Long-running Roslyn workspaces can
retain stale references after restore or project-framework changes;
rebuilding or suppressing diagnostics is not the first remedy.

C# project loading also requires the server's .NET runtime, a .NET SDK,
framework reference assemblies, and restored NuGet dependencies. Use the checkout's
normal developer setup and restore/build process; Neovim does not
automatically restore packages. Generated-source projects also need their build
prerequisites generated in this same checkout and configuration. After completing
restore/build, run `:lsp restart roslyn_ls` to reload a previously failed project
load. See `..\troubleshooting\nvim-csharp-missing-generated-references.md`
for missing FSM/EntityFx references and schema-generation failures.

Loading a large solution can take time.
All solution projects load so cross-project definitions and reference
searches remain complete. Analyzers run only against open documents.

Use `:checkhealth vim.lsp` to inspect Roslyn status, and
`:TSInstall c_sharp sql rust powershell` to retry missing
parsers. Restart Neovim after changing this configuration.

See `..\troubleshooting\nvim-csharp-project-loading.md` for C# workspace
loading failures and their fix.

The Ruby extra is disabled; Orcas C# development does not require it.
If Ruby support is needed, install Ruby with `gem` available on PATH
before enabling the Ruby extra in `:LazyExtras`. See
`..\troubleshooting\nvim-ruby-tools-missing-gem.md` for installation errors.
