# Neovim UI animations are distracting

## Symptom

Scrolling, indent-guide transitions, cursor blinking, and the LSP progress
spinner add unwanted motion while editing.

## Root cause

LazyVim enables Snacks animations globally by default. Neovim also permits
cursor blinking in terminal mode, and Noice's default LSP progress format
includes an animated spinner.

## Fix

`nvim\lua\config\options.lua` sets `vim.g.snacks_animate = false` to disable
Snacks animations. It appends `a:blinkon0` to `guicursor` to disable blinking
in all modes without changing cursor shapes.

`nvim\lua\plugins\animations.lua` replaces the animated LSP progress
spinner with text containing the title, client, percentage, and message.
Progress reporting remains enabled.

Restart Neovim to apply the defaults. Normal scrolling, static indent
guides, diagnostics, and navigation remain available. Windows Terminal
and WezTerm settings are unchanged.

## Prevention

- Keep animation preferences in the early-loaded options file.
- Use the global Snacks animation setting rather than disabling useful
  UI components.
- Avoid enabling additional animation extras in `:LazyExtras`.
