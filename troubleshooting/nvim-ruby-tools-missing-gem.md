# Neovim tries to install Ruby tools without Ruby

## Symptom

Opening a source file shows Mason errors for `ruby_lsp` and `rubocop`.
Mason's log also reports failed installs for `erb-formatter` and `erb-lint`,
with `Could not find executable "gem" in PATH`.

The separate Roslyn `Initializing` notification is normal C# solution
loading, not a Ruby installation error.

## Root cause

`nvim\lazyvim.json` enabled `lazyvim.plugins.extras.lang.ruby`.
That extra adds Ruby servers and ERB tools to Mason's installation lists.
Loading the LSP plugins triggers those installations even when the
opened file is C#. The tools require Ruby's `gem` executable, which was
not available on PATH.

## Fix

Remove the Ruby extra from `nvim\lazyvim.json` and restart Neovim.
This stops the automatic Ruby installations without changing the .NET
extra, Roslyn, or C# navigation.

## Prevention

- Enable only the language extras needed for development.
- Before enabling the Ruby extra in `:LazyExtras`, install Ruby and
  confirm that `ruby` and `gem` are available in the editor's PATH.
- Inspect `:MasonLog` for the failing package's actual dependency error.
- Do not disable Mason notifications to hide a missing runtime.
