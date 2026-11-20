local M = {}
local configured = false

function M.setup()
  if configured then
    return
  end
  local inline = require("diffview.scene.inline_diff")
  local windows = {}
  local attach, detach = inline.attach_to_window, inline.detach
  inline.attach_to_window = function(buffer, win)
    attach(buffer, win)
    if not windows[win] then
      windows[win] = {
        virtualedit = vim.api.nvim_get_option_value("virtualedit", { win = win, scope = "local" }),
        wrap = vim.wo[win].wrap,
      }
    end
    windows[win].buffer = buffer
    -- Native scrolling must be able to move past a shorter new-side line.
    vim.wo[win].virtualedit = "all"
    vim.wo[win].wrap = false
  end
  inline.detach = function(buffer)
    for win, saved in pairs(windows) do
      if saved.buffer == buffer then
        if vim.api.nvim_win_is_valid(win) then
          vim.wo[win].virtualedit = saved.virtualedit
          vim.wo[win].wrap = saved.wrap
        end
        windows[win] = nil
      end
    end
    detach(buffer)
  end
  local render = inline.render
  inline.render = function(buffer, ...)
    render(buffer, ...)
    if not vim.api.nvim_buf_is_valid(buffer) then
      return
    end
    -- The pinned renderer leaves deleted virtual rows at Neovim's truncation default.
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buffer, inline.ns, 0, -1, { details = true })) do
      local details = mark[4]
      if details.virt_lines then
        vim.api.nvim_buf_set_extmark(buffer, inline.ns, mark[2], mark[3], {
          id = mark[1],
          virt_lines = details.virt_lines,
          virt_lines_above = details.virt_lines_above,
          virt_lines_leftcol = details.virt_lines_leftcol,
          virt_lines_overflow = "scroll",
          priority = details.priority,
          right_gravity = details.right_gravity,
        })
      end
    end
  end
  configured = true
end

return M
