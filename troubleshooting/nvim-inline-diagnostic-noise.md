# Neovim inline style diagnostics obscure source code

## Symptom

C# files show many inline style suggestions such as "Name can be
simplified", crowding source lines with repeated diagnostic text and green
squiggly underlines beneath qualifiers such as `this`.

## Root cause

LazyVim enables diagnostic virtual text and underlines without severity filters.
Roslyn's informational and hint diagnostics therefore appear inline
alongside compiler errors and warnings. These diagnostic messages are
separate from parameter/type inlay hints.

## Fix

`nvim\lua\plugins\diagnostics.lua` sets the minimum severity for diagnostic
virtual text and underlines to `vim.diagnostic.severity.WARN`. Only errors
and warnings appear as inline text or squiggly underlines, for all languages.

All diagnostics remain available through `<leader>cd` (line diagnostics).
Signs, analyzers, and C# parameter/type inlay hints are
unchanged. This is a presentation filter, not suppression of diagnostics
in the source repository.

Restart Neovim after changing the configuration.

## Prevention

- Filter diagnostic virtual text and underlines separately from diagnostic
  collection.
- Keep compiler errors and warnings visible.
- Do not disable C# inlay hints to hide diagnostic messages; they are
  independent features.
