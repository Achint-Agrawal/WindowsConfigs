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
| `<leader>sg` | Search text |
| `Ctrl+o` | Return after a navigation jump |

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
