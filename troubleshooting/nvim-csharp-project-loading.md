# Neovim C# navigation cannot find project definitions

## Symptom

C# syntax highlighting works and OmniSharp attaches, but definitions,
completion, and diagnostics cannot resolve the project's symbols.
The LSP log reports `No solution files found` in the editor's launch
directory, even though the client's `root_dir` points to a solution.

After explicitly selecting the RP solution, full OmniSharp initialization
still fails to finish in a reasonable time. On-demand loading lets local
definitions resolve but misses cross-project definitions.

Orcas shared projects can also start separate, incomplete workspaces
because their `.csproj` files are not below the main `.sln` directory.

## Root cause

The default OmniSharp command does not pass a solution location with
`-s`. OmniSharp initializes its workspace from its process working
directory, which Neovim does not automatically set to `root_dir`.
Launching Neovim outside the solution directory can therefore produce
an initialized language server with no loaded C# projects.

Normal ancestor-based root detection cannot find a solution located in
a sibling directory, as is the case for several Orcas RP projects.

## Fix

`nvim\lua\plugins\dotnet.lua` preserves LazyVim's .NET tooling but disables
OmniSharp for C#. It uses nvim-lspconfig's modern `roslyn_ls` integration,
which explicitly opens the selected solution through `solution/open`.
The server is taken from PATH or the newest installed VS Code C# extension.

An ancestor `.sln` or `.slnx` remains the first choice. Orcas source files
without an ancestor solution fall back to the RP solution, found using
the checkout's `dirs.proj` and the relative RP solution path. This avoids
hard-coding a machine-specific checkout path.

All solution projects load to preserve cross-project definitions and
references; background diagnostics are limited to open documents.
Missing NuGet dependencies produce a visible restore warning rather
than triggering an automatic restore.

`nvim\lua\plugins\treesitter-extras.lua` also installs the SQL, Rust, and
PowerShell parsers. `nvim\lua\config\options.lua` recognizes additional
MSBuild and resource-file extensions as XML.

## Prevention

- Keep the .NET extra enabled in `nvim\lazyvim.json`.
- Keep Roslyn enabled and OmniSharp disabled for C# to avoid duplicate
  language servers and conflicting navigation mappings.
- Keep the VS Code C# extension and its required .NET runtime installed,
  or install `roslyn-language-server` on PATH.
- Use `<leader>cl` or `:checkhealth vim.lsp` to inspect the attached server.
- Check `:lua print(vim.lsp.log.get_filename())` for the LSP log path.
- Install the project's .NET SDK and reference assemblies, and restore
  its dependencies using the normal developer workflow.
- Open projects outside the RP solution and its references under their
  own solution; syntax highlighting alone does not establish LSP health.
