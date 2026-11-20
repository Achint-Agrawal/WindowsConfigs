local root =
  assert(vim.env.NVIM_INLINE_SCROLL_TEST_DIR, "Set NVIM_INLINE_SCROLL_TEST_DIR to a fresh temporary directory")
local output = {}
local original_stdpath = vim.fn.stdpath
vim.fn.stdpath = function(kind)
  return kind == "state" and vim.fs.joinpath(root, "state") or original_stdpath(kind)
end

local function check(value, message)
  assert(value, message)
  output[#output + 1] = "OK " .. message
end

local function screen()
  vim.cmd.redraw()
  local rows = {}
  for row = 1, vim.o.lines do
    local cells = {}
    for col = 1, vim.o.columns do
      cells[#cells + 1] = vim.fn.screenstring(row, col)
    end
    rows[#rows + 1] = table.concat(cells)
  end
  return table.concat(rows, "\n")
end

local function run()
  vim.o.columns, vim.o.lines = 110, 36
  local fixture = vim.fs.joinpath(root, "fixture")
  assert(vim.fn.isdirectory(fixture) == 0, "Use a fresh test directory")
  vim.fn.mkdir(fixture, "p")
  local function git(...)
    local command = {
      "git",
      "-c",
      "user.name=Fixture",
      "-c",
      "user.email=fixture@example.invalid",
      "-c",
      "commit.gpgsign=false",
      "-c",
      "core.hooksPath=NUL",
    }
    vim.list_extend(command, { ... })
    local result = vim.system(command, { cwd = fixture, text = true }):wait()
    assert(result.code == 0, result.stderr)
    return vim.trim(result.stdout)
  end
  git("init", "--quiet")
  local old, new = {}, {}
  for row = 1, 25 do
    old[row], new[row] = "unchanged line " .. row, "unchanged line " .. row
  end
  local deleted = "removed " .. string.rep("x", 220) .. " DELETED_LINE_TAIL"
  old[10], new[10] = deleted, "new"
  vim.fn.writefile(old, vim.fs.joinpath(fixture, "a.txt"))
  vim.fn.writefile({ deleted }, vim.fs.joinpath(fixture, "b-deleted.txt"))
  git("add", ".")
  git("commit", "--quiet", "-m", "Inline scroll base")
  vim.fn.writefile(new, vim.fs.joinpath(fixture, "a.txt"))
  assert(vim.fn.delete(vim.fs.joinpath(fixture, "b-deleted.txt")) == 0)
  git("add", ".")
  git("commit", "--quiet", "-m", "Inline scroll changes")
  local head = git("rev-parse", "HEAD")
  local global_virtualedit = vim.api.nvim_get_option_value("virtualedit", { scope = "global" })
  local original_virtualedit = vim.wo.virtualedit
  local original = vim.api.nvim_get_current_buf()
  local original_mapping = vim.fn.maparg("zl", "n", false, true)
  require("lazy").load({ plugins = { "ado-pr.nvim" } })
  vim.api.nvim_set_current_dir(fixture)
  vim.cmd("DiffviewOpen HEAD~1..HEAD")
  local lib = require("diffview.lib")
  local view
  local function ready(path)
    assert(
      vim.wait(15000, function()
        view = lib.get_current_view()
        local loading = view and view:set_file_in_flight()
        return view
          and view.cur_entry
          and view.cur_entry.path == path
          and view.cur_entry.opened
          and (not loading or loading:is_done())
      end, 25),
      "Diffview did not finish loading " .. path
    )
    vim.wait(200)
  end
  ready("a.txt")
  local function key(keys)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
    vim.wait(100)
  end
  local function toggle(layout)
    key(" gv")
    assert(
      vim.wait(15000, function()
        local loading = view:set_file_in_flight()
        local win = view.cur_layout:get_main_win()
        return view.cur_layout.name == layout
          and (not loading or loading:is_done())
          and win
          and win.file
          and win.file:is_valid()
          and vim.api.nvim_win_is_valid(win.id)
      end, 25),
      "The layout toggle did not finish opening " .. layout
    )
    vim.wait(200)
  end
  local function inspect_deletion()
    local buffer = view.cur_layout:get_main_win().file.bufnr
    local ns = require("diffview.scene.inline_diff").ns
    local count = 0
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buffer, ns, 0, -1, { details = true })) do
      if mark[4].virt_lines then
        count = count + 1
        check(mark[4].virt_lines_overflow == "scroll", "Deleted rows use horizontally scrollable virtual lines")
      end
    end
    check(count > 0, "The real inline renderer emitted a deleted row")
  end
  local function position(line)
    local win = view.cur_layout:get_main_win().id
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_win_set_cursor(win, { line, 0 })
    vim.wo.wrap = false
    if line > 1 then
      vim.cmd("normal! zz")
    end
    return win
  end
  position(10)
  check(not screen():find("DELETED_LINE_TAIL", 1, true), "A narrow inline pane initially clips the long deleted suffix")
  key("210zl")
  check(
    screen():find("DELETED_LINE_TAIL", 1, true),
    "Horizontal scrolling reveals the deleted suffix beside a shorter new line"
  )
  check(
    vim.wo.virtualedit == "all"
      and vim.api.nvim_get_option_value("virtualedit", { scope = "global" }) == global_virtualedit,
    "Scrolling past short lines is enabled only in the inline window"
  )
  inspect_deletion()
  key("210zh")
  check(
    vim.fn.winsaveview().leftcol == 0 and screen():find("removed ", 1, true),
    "Scrolling left returns to the deleted line's beginning"
  )
  key("6zL")
  check(vim.fn.winsaveview().leftcol > 200, "Half-window scrolling honors a count beyond the new line's end")
  key("6zH")
  check(vim.fn.winsaveview().leftcol == 0, "Half-window scrolling can return left")

  local renderer = require("diffview.scene.inline_diff")
  renderer.render(view.cur_layout:get_main_win().file.bufnr, old, new, { style = "unified" })
  inspect_deletion()
  key("210zl")
  check(screen():find("DELETED_LINE_TAIL", 1, true), "Deleted text remains scrollable after a renderer refresh")
  key("210zh")
  toggle("diff2_horizontal")
  check(view.cur_layout.name == "diff2_horizontal", "The inline toggle still opens the old/new side-by-side layout")
  check(vim.wo.virtualedit == original_virtualedit, "Side-by-side diffs restore normal virtual editing")
  toggle("diff1_inline")
  ready("a.txt")
  position(10)
  key("210zl")
  check(screen():find("DELETED_LINE_TAIL", 1, true), "Deleted text remains scrollable after toggling back to inline")
  key("210zh")
  for _, entry in view.files:iter() do
    if entry.path == "b-deleted.txt" then
      view:set_file(entry, true)
      break
    end
  end
  ready("b-deleted.txt")
  position(1)
  inspect_deletion()
  key("210zl")
  check(
    screen():find("DELETED_LINE_TAIL", 1, true),
    "A wholly deleted file scrolls even though its real buffer is empty"
  )
  inspect_deletion()
  vim.cmd("DiffviewClose")
  vim.api.nvim_set_current_buf(original)
  check(
    vim.deep_equal(vim.fn.maparg("zl", "n", false, true), original_mapping),
    "Closing the review leaves ordinary-buffer scrolling unchanged"
  )
  check(
    vim.wo.virtualedit == original_virtualedit
      and vim.api.nvim_get_option_value("virtualedit", { scope = "global" }) == global_virtualedit,
    "Review close restores normal virtual editing without global changes"
  )
  check(
    git("rev-parse", "HEAD") == head and git("status", "--porcelain") == "",
    "Reading long deleted lines does not change Git history, the index, or files"
  )
  output[#output + 1] = "PASS"
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.defer_fn(function()
      local ok, err = xpcall(run, debug.traceback)
      if not ok then
        output[#output + 1] = err
        output[#output + 1] = screen()
      end
      vim.fn.mkdir(root, "p")
      vim.fn.writefile(
        vim.split(table.concat(output, "\n"), "\n", { plain = true }),
        vim.fs.joinpath(root, "results.log")
      )
      vim.cmd(ok and "qa!" or "cquit")
    end, 500)
  end,
})
