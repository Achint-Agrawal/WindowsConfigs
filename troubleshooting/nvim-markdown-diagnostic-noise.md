# Markdown formatting and spelling obscure technical reports

## Symptom

Technical Markdown reports show repeated inline `MD013/line-length` messages
for lines longer than 80 characters, and `MD060` table-alignment warnings.
Red spelling underlines appear under technical identifiers, acronyms, and
source-code references.

## Root cause

LazyVim's Markdown extra enables markdownlint through nvim-lint.
Markdownlint formatting rules have warning severity, so the existing
errors/warnings-only diagnostic filter intentionally still displays them.
They are separate from Marksman language-server diagnostics.

LazyVim also enables the window-local `spell` option for Markdown.
Spelling underlines are not diagnostics and cannot be hidden with a
diagnostic severity filter.

## Fix

`nvim\lua\plugins\diagnostics.lua` disables virtual text and diagnostic
underlines only for nvim-lint's `markdownlint-cli2` namespace. The original
lint results, severities, gutter signs, and project rules remain unchanged.
Use `<leader>cd` (Space, c, d) to see diagnostics on the current line.
Other Markdown diagnostic sources and diagnostics in other languages retain
their normal display.

`nvim\lua\config\autocmds.lua` disables spelling by default for `markdown`
and `markdown.mdx`, after LazyVim's default FileType handler. It leaves
wrapping and Markdown rendering alone. Use `<leader>us` (Space, u, s) or
`:setlocal spell` to enable spelling temporarily; use the toggle again or
`:setlocal nospell` to turn it off.

Restart Neovim after updating the configuration. No report content is
rewritten, lint rule disabled, or linter stopped.

## Prevention

- Keep formatting-lint presentation scoped to its diagnostic namespace,
  rather than disabling all Markdown or global diagnostics.
- Keep lint collection available for explicit inspection.
- Treat spell-check and diagnostic highlighting as independent controls.

`nvim\tests\markdown-diagnostics.lua` runs real markdownlint against a
synthetic report, verifies quiet inline display and on-demand diagnostics,
checks the spelling toggle, and preserves other diagnostic sources.
Set `NVIM_MARKDOWN_TEST_DIR` to a fresh temporary directory and run
`nvim --headless -i NONE --cmd "lua dofile([[<absolute test script path>]])"`.
