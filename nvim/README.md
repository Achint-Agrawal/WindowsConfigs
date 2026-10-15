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

`lua\plugins\diagnostics.lua` controls this display filter; it does not
disable analyzers or remove diagnostics. See
`..\troubleshooting\nvim-inline-diagnostic-noise.md` for details.

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

C# project loading also requires the server's .NET runtime, a .NET SDK,
framework reference assemblies, and restored NuGet dependencies. Use the checkout's
normal developer setup and restore/build process; Neovim does not
automatically restore packages. Loading a large solution can take time.
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
