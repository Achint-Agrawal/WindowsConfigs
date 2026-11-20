# Long deleted lines cannot scroll in inline PR diffs

## Symptom

An inline ADO PR diff shows a long red deleted line cut off at the right edge.
Moving the cursor right or using horizontal scroll keys cannot reveal its
end, especially when the replacement line is much shorter.

## Root cause

Diffview Plus renders deleted lines as virtual rows attached to the new-side
buffer. The pinned renderer leaves `virt_lines_overflow` at Neovim's default,
`trunc`, so those rows do not follow horizontal scrolling.

There is a second limitation: without virtual editing, native horizontal
scrolling cannot move the cursor beyond the real new-side line's last column.
Changing only the virtual-row overflow flag still leaves long deletions
unreadable beside short or empty replacement lines.

## Fix

`nvim\lua\config\diffview-inline.lua`, initialized by
`nvim\lua\plugins\ado-pr.lua`, adapts the inline renderer in memory:

- Deleted virtual rows use `virt_lines_overflow = "scroll"` after every render.
- Inline windows use `nowrap` and window-local `virtualedit=all`, so native
scrolling can move past short new-side lines.
- Detaching the inline renderer restores the previous window options.
No global mappings or options, installed dependency files, or plugin pins change.

Restart Neovim to load the configuration, then focus the diff pane:

| Key | Action |
| --- | --- |
| `zL` / `zH` | Scroll half a window right/left |
| `zl` / `zh` | Scroll one column right/left |
| `20zl` / `20zh` | Scroll 20 columns right/left |
| `Space g v` | Toggle side-by-side to read the old version in a real buffer |

Virtual columns are not file content. PR commit buffers remain read-only.
In an editable working-tree diff, entering text beyond a line's end can
insert padding because virtual editing is enabled in the inline window.

## Prevention

Keep both the scrollable virtual rows and the inline-only virtual editing
when updating Diffview Plus; either change alone is insufficient.

Run the screen-level regression with `NVIM_INLINE_SCROLL_TEST_DIR` set to a
fresh temporary directory:

```text
nvim --headless -i NONE --cmd "lua dofile([[<absolute path to nvim\tests\diffview-inline-scroll.lua>]])"
```

The test first reproduces clipping in a narrow pane and then checks that
the actual screen shows the deleted suffix after scrolling. It also covers
counted column/half-window scrolling, renderer refresh, toggling layouts,
a wholly deleted file, option restoration, and unchanged Git files/index.
Fixtures and local review state are isolated under the supplied directory;
no ADO requests, real PR checkouts, comments, or votes are made.
