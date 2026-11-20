local root = assert(vim.env.NVIM_REVIEW_TEST_DIR, "Set NVIM_REVIEW_TEST_DIR to a temporary test directory")
local phase = vim.env.NVIM_REVIEW_TEST_PHASE or "write"
local output = {}
local original_stdpath = vim.fn.stdpath
vim.fn.stdpath = function(kind)
  return kind == "state" and vim.fs.joinpath(root, "state") or original_stdpath(kind)
end

local function check(value, message)
  assert(value, message)
  output[#output + 1] = "OK " .. message
end

local function run()
  local fixture = vim.fs.joinpath(root, "fixture")
  local function binary(text)
    local file = assert(vim.uv.fs_open(vim.fs.joinpath(fixture, "z.bin"), "w", 438))
    assert(vim.uv.fs_write(file, text, 0))
    assert(vim.uv.fs_close(file))
  end
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

  if phase == "write" then
    assert(vim.fn.isdirectory(fixture) == 0, "Use a fresh test directory")
    vim.fn.mkdir(fixture, "p")
    git("init", "--quiet")
    for _, name in ipairs({ "a.txt", "b.txt", "c-deleted.txt", "e-edges.txt" }) do
      local lines = {}
      for line = 1, 120 do
        lines[line] = name .. " line " .. line
      end
      vim.fn.writefile(lines, vim.fs.joinpath(fixture, name))
    end
    binary("old\0binary")
    git("add", ".")
    git("commit", "--quiet", "-m", "Fixture base")
    for _, name in ipairs({ "a.txt", "b.txt" }) do
      local path = vim.fs.joinpath(fixture, name)
      local lines = vim.fn.readfile(path)
      lines[10], lines[100] = "first change", "last change"
      vim.fn.writefile(lines, path)
    end
    assert(vim.fn.delete(vim.fs.joinpath(fixture, "c-deleted.txt")) == 0)
    vim.fn.writefile({ "new file" }, vim.fs.joinpath(fixture, "d-added.txt"))
    local edge_path = vim.fs.joinpath(fixture, "e-edges.txt")
    local edges = vim.fn.readfile(edge_path)
    table.remove(edges, 1)
    table.remove(edges)
    edges[1], edges[#edges] = "changed " .. edges[1], "changed " .. edges[#edges]
    vim.fn.writefile(edges, edge_path)
    binary("new\0binary")
    git("add", ".")
    git("commit", "--quiet", "-m", "Fixture changes")
  end

  local head = git("rev-parse", "HEAD")
  require("lazy").load({ plugins = { "ado-pr.nvim" } })
  require("config.diffview-review")
  local lib = require("diffview.lib")
  local selections = require("diffview.api").selections
  vim.cmd.cd(vim.fn.fnameescape(fixture))
  local function open(range)
    vim.cmd("DiffviewOpen " .. range)
    assert(
      vim.wait(15000, function()
        local view = lib.get_current_view()
        return view and view.cur_entry and view.cur_entry.opened
      end, 50),
      "Diffview did not open"
    )
    vim.wait(150)
    return assert(lib.get_current_view())
  end
  local view = open("HEAD~1..HEAD")
  local function main()
    return view.cur_layout:get_main_win()
  end
  local function cursor(line, side)
    local window = side and view.cur_layout[side] or main()
    vim.api.nvim_set_current_win(window.id)
    vim.api.nvim_win_set_cursor(window.id, { line, 0 })
  end
  local function key(keys)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
    vim.wait(150)
  end
  local function wait_file(name, line)
    assert(
      vim.wait(15000, function()
        local loading = view:set_file_in_flight()
        return view.cur_entry.path == name
          and view.cur_entry.opened
          and (not loading or loading:is_done())
          and vim.api.nvim_win_get_cursor(main().id)[1] == line
      end, 25),
      "Expected unreviewed hunk at "
        .. name
        .. ":"
        .. line
        .. ", actual "
        .. view.cur_entry.path
        .. ":"
        .. vim.api.nvim_win_get_cursor(main().id)[1]
    )
  end
  local marked_buffers = {}
  local function marks()
    local namespace = vim.api.nvim_get_namespaces()["DiffviewHunkReview:" .. view.tabpage]
    assert(namespace, "Missing hunk-review namespace")
    marked_buffers[namespace] = marked_buffers[namespace] or {}
    marked_buffers[namespace][main().file.bufnr] = true
    return vim.api.nvim_buf_get_extmarks(main().file.bufnr, namespace, 0, -1, { details = true })
  end
  local function reviewed_count()
    local count = 0
    for _, mark in ipairs(marks()) do
      if mark[4].virt_text[1][1]:find("[x]", 1, true) then
        count = count + 1
      end
    end
    return count
  end

  if phase == "reload" then
    check(reviewed_count() == 1, "Partial hunk progress survives a separate Neovim process")
    check(selections.is_selected("b.txt"), "Complete-file progress survives a separate Neovim process")
    key("]r")
    wait_file("a.txt", 100)
    key(" ghw")
    check(selections.is_selected("a.txt"), "Restored partial progress completes the file")
    vim.cmd("DiffviewClose")
  elseif phase == "guard" then
    vim.cmd("DiffviewClose")
    local saved = {}
    local directory = vim.fs.joinpath(root, "state", "diffview-hunk-review")
    for _, path in ipairs(vim.fn.globpath(directory, "*.json", false, true)) do
      saved[path] = vim.fn.readfile(path, "b")
      vim.fn.writefile({ "invalid-json" }, path, "b")
    end
    check(next(saved) ~= nil, "A saved-progress file exists for error-handling checks")
    local notifications, original_notify = {}, vim.notify
    vim.notify = function(message, level)
      notifications[#notifications + 1] = { message = message, level = level }
    end
    view = open("HEAD~1..HEAD")
    key(" ghw")
    check(
      vim.iter(notifications):any(function(item)
        return item.level == vim.log.levels.ERROR and item.message:find("Invalid review progress", 1, true)
      end),
      "Corrupted progress raises an explicit error"
    )
    for path, lines in pairs(saved) do
      check(vim.fn.readfile(path, "b")[1] == "invalid-json", "Invalid saved progress is not overwritten")
      vim.fn.writefile(lines, path, "b")
    end
    vim.cmd("DiffviewClose")
    view = open("HEAD~1")
    key("]r")
    check(
      vim.iter(notifications):any(function(item)
        return item.level == vim.log.levels.WARN and item.message:find("commit-to-commit", 1, true)
      end),
      "Mutable working-tree diffs do not inherit saved PR review marks"
    )
    vim.cmd("DiffviewClose")
    vim.notify = original_notify
  else
    check(#marks() == 2 and reviewed_count() == 0, "Both inline hunks start unreviewed")
    key(" ghw")
    check(
      reviewed_count() == 1 and not selections.is_selected("a.txt"),
      "A reviewed hunk does not prematurely mark its file"
    )
    key("]r")
    wait_file("a.txt", 100)
    key(" ghw")
    check(reviewed_count() == 2 and selections.is_selected("a.txt"), "All reviewed hunks automatically mark the file")
    key(" ghw")
    check(reviewed_count() == 1 and not selections.is_selected("a.txt"), "Unreviewing a hunk unmarks its file")
    cursor(50)
    key(" ghw")
    check(reviewed_count() == 1, "Unchanged context cannot be marked as a hunk")

    cursor(10)
    key(" gv")
    check(
      view.cur_layout.name == "diff2_horizontal" and reviewed_count() == 1,
      "Progress survives switching to side-by-side"
    )
    cursor(100, "a")
    key(" ghw")
    check(selections.is_selected("a.txt"), "A left-pane hunk maps to the same reviewed state")
    key("]r")
    wait_file("b.txt", 10)
    cursor(100)
    key("[r")
    wait_file("b.txt", 10)
    key(" ghw")
    key("]r")
    wait_file("b.txt", 100)
    key(" ghw")
    check(selections.is_selected("b.txt"), "Both panes and both hunks synchronize file completion")
    require("diffview.actions").focus_files()
    key("H")
    check(view.panel.hide_selected, "Completed files can be hidden with H")

    key("]r")
    wait_file("c-deleted.txt", 1)
    key(" ghw")
    check(selections.is_selected("c-deleted.txt"), "Whole-file deletion is reviewable")
    key("]r")
    wait_file("d-added.txt", 1)
    key(" ghw")
    check(selections.is_selected("d-added.txt"), "Whole-file addition is reviewable")
    key("]r")
    wait_file("e-edges.txt", 1)
    check(#marks() == 2, "Overlapping linematch sub-hunks form reviewable cursor groups")
    key(" ghw")
    key(" gv")
    check(
      view.cur_layout.name == "diff1_inline" and reviewed_count() == 1,
      "Edge-hunk progress matches in both layouts"
    )
    key("]r")
    wait_file("e-edges.txt", 118)
    key(" ghw")
    check(selections.is_selected("e-edges.txt"), "Beginning/end deletion anchors can both be reviewed")

    local entry
    for _, file in view.files:iter() do
      if file.path == "a.txt" then
        entry = file
      end
    end
    view:set_file(assert(entry), true)
    assert(vim.wait(15000, function()
      return view.cur_entry == entry and entry.opened and #marks() == 2
    end, 25))
    cursor(100)
    key(" ghw")
    check(reviewed_count() == 1, "A partial file can be saved for restart")

    require("diffview.actions").focus_files()
    key("H")
    view.panel:highlight_file(entry)
    key("w")
    check(reviewed_count() == 2 and selections.is_selected("a.txt"), "Native w marks every hunk in the selected file")
    view.panel:highlight_file(entry)
    key("w")
    check(
      reviewed_count() == 0 and not selections.is_selected("a.txt"),
      "Native w unmarks every hunk in the selected file"
    )
    cursor(10)
    key(" ghw")
    local other
    for _, file in view.files:iter() do
      if file.path == "b.txt" then
        other = file
      end
    end
    view:set_file(other, true)
    wait_file("b.txt", 100)
    key("]r")
    wait_file("a.txt", 100)
    check(reviewed_count() == 1, "Unread navigation skips non-text changes and wraps to a partially reviewed file")
    vim.cmd("DiffviewClose")
    view = open("HEAD~1..HEAD")
    check(
      reviewed_count() == 1 and selections.is_selected("b.txt"),
      "Reopening the exact diff restores partial and whole-file progress"
    )
    key("]r")
    wait_file("a.txt", 100)
    key(" ghw")
    key("]r")
    wait_file("a.txt", 100)
    check(selections.count() == 5, "All-text-reviewed navigation terminates without marking the binary file")
    key(" ghw")

    local diff_api = require("diffview.api")
    diff_api.set_revs("HEAD~1..HEAD~1")
    assert(vim.wait(10000, function()
      return view.files:len() == 0
    end, 25))
    diff_api.set_revs("HEAD..HEAD~1")
    assert(vim.wait(15000, function()
      return view.cur_entry and view.cur_entry.opened and view.files:len() > 0 and view.cur_entry.revs.a.commit == head
    end, 25))
    vim.wait(150)
    check(selections.count() == 0 and reviewed_count() == 0, "Changing revisions in place resets stale marks")
    vim.cmd("DiffviewClose")
  end
  check(
    git("rev-parse", "HEAD") == head and git("status", "--porcelain") == "",
    "Review never edits the checkout or index"
  )
  for namespace, buffers in pairs(marked_buffers) do
    for buffer in pairs(buffers) do
      assert(
        not vim.api.nvim_buf_is_valid(buffer) or #vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, {}) == 0,
        "Review markers leaked after closing Diffview"
      )
    end
  end
  check(true, "Closing Diffview clears hunk markers")
  check(vim.fn.maparg(" ghw", "n") == "", "Hunk-review shortcut is not global")
  output[#output + 1] = "PASS"
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.defer_fn(function()
      local ok, err = xpcall(run, debug.traceback)
      if not ok then
        vim.list_extend(output, vim.split(err, "\n", { plain = true }))
        local view = require("diffview.lib").get_current_view()
        if view and view.files then
          for _, entry in view.files:iter() do
            local files = {}
            for _, side in ipairs({ "a", "b" }) do
              local file = entry.layout:get_file_for(side)
              files[side] = file
                and {
                  nulled = file.nulled,
                  binary = file.binary,
                  buffer = file.bufnr,
                  lines = file.bufnr
                    and vim.api.nvim_buf_is_valid(file.bufnr)
                    and vim.api.nvim_buf_get_lines(file.bufnr, 0, -1, false),
                }
            end
            output[#output + 1] = vim.json.encode({ entry.path, entry.layout.name, files })
          end
        end
      end
      vim.fn.mkdir(root, "p")
      vim.fn.writefile(output, vim.fs.joinpath(root, phase .. ".log"))
      vim.cmd(ok and "qa!" or "cquit")
    end, 500)
  end,
})
