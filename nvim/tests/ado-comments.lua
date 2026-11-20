local root = assert(vim.env.NVIM_COMMENT_TEST_DIR, "Set NVIM_COMMENT_TEST_DIR to a fresh temporary directory")
local output = {}
local stdpath = vim.fn.stdpath
vim.fn.stdpath = function(kind)
  return kind == "state" and vim.fs.joinpath(root, "state") or stdpath(kind)
end

local function check(value, message)
  assert(value, message)
  output[#output + 1] = "OK " .. message
end

local function run()
  vim.v.errmsg = ""
  local function global_navigation()
    local result = {}
    for _, mapping in ipairs(vim.api.nvim_get_keymap("n")) do
      if mapping.lhs == "]T" or mapping.lhs == "[T" then
        result[mapping.lhs] = { rhs = mapping.rhs, desc = mapping.desc, sid = mapping.sid }
      end
    end
    return result
  end
  local original_navigation = global_navigation()
  local unchanged = "unchanged%{1+1}.txt"
  local fixture = vim.fs.joinpath(root, "fixture")
  assert(vim.fn.isdirectory(fixture) == 0, "Use a fresh test directory")
  vim.fn.mkdir(fixture, "p")
  local function git(...)
    local args = {
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
    vim.list_extend(args, { ... })
    local result = vim.system(args, { cwd = fixture, text = true }):wait()
    assert(result.code == 0, result.stderr)
    return vim.trim(result.stdout)
  end
  for _, name in ipairs({ "alpha.txt", "beta.txt", "deleted.txt", "old-name.txt", unchanged }) do
    local lines = {}
    for line = 1, 120 do
      lines[line] = name .. " line " .. line
    end
    vim.fn.writefile(lines, vim.fs.joinpath(fixture, name))
  end
  git("init", "--quiet")
  git("add", ".")
  git("commit", "--quiet", "-m", "Comment fixture base")
  local base = git("rev-parse", "HEAD")
  for _, name in ipairs({ "alpha.txt", "beta.txt" }) do
    local path = vim.fs.joinpath(fixture, name)
    local lines = vim.fn.readfile(path)
    lines[10] = "changed " .. name
    vim.fn.writefile(lines, path)
  end
  assert(vim.fn.delete(vim.fs.joinpath(fixture, "deleted.txt")) == 0)
  git("mv", "old-name.txt", "new-name.txt")
  git("add", ".")
  git("commit", "--quiet", "-m", "Comment fixture changes")
  local head = git("rev-parse", "HEAD")
  vim.fn.writefile({ "Local draft, not the reviewed commit" }, vim.fs.joinpath(fixture, unchanged))
  local original_status = git("status", "--porcelain")
  require("lazy").load({ plugins = { "ado-pr.nvim" } })
  local comments = require("config.ado-comments")
  local state, az = require("ado-pr.state"), require("ado-pr.az")
  local context =
    { id = 42, repositoryId = "fixture", project = "Fixture", repo_root = fixture, base = base, pr_base = base }
  state.set(context)
  local function thread(id, path, line, side, status)
    local item = {
      id = id,
      status = status or "active",
      comments = {
        {
          id = 1,
          commentType = "text",
          author = { displayName = "Reviewer" },
          publishedDate = "2026-01-01",
          content = "Comment " .. id,
        },
      },
    }
    if path then
      item.threadContext = { filePath = "/" .. path }
      if line then
        item.threadContext[side == "left" and "leftFileStart" or "rightFileStart"] = { line = line, offset = 1 }
      end
    end
    return item
  end
  local payload = {
    thread(1, "beta.txt", 90),
    thread(2, "alpha.txt", 70),
    thread(3, "alpha.txt", 30, "left", "fixed"),
    thread(4, "deleted.txt", 50, "left"),
    thread(5, "old-name.txt", 35, "left"),
    thread(6, unchanged, 75),
    thread(7),
    thread(8),
    thread(9),
    thread(10, "historic.txt", 60),
    thread(11, unchanged),
    thread(12, "beta.txt", 999),
    thread(13),
    thread(14),
  }
  payload[1].comments[1].content = "First line\nSecond line"
  payload[1].comments[2] = {
    id = 2,
    parentCommentId = 1,
    commentType = "text",
    author = { displayName = "Author" },
    publishedDate = "2026-01-02",
    content = "Reply with searchable text",
  }
  payload[8].comments[1].commentType = "system"
  payload[9].comments[1].isDeleted = true
  payload[13].comments[1].commentType = 3
  payload[13].comments[2] = {
    id = 2,
    commentType = "text",
    author = { displayName = "Reviewer" },
    content = "Human reply to system thread",
  }
  payload[14].isDeleted = true
  local reads, fail_reads = 0, false
  az.list_threads = function()
    reads = reads + 1
    if fail_reads then
      return nil, "fixture read failure"
    end
    return payload
  end
  az.list_threads_tracked = function(_, iteration, base_iteration)
    check(iteration == 1 and base_iteration == 1, "Tracked reads use the current iteration window")
    local tracked = {}
    for _, id in ipairs({ 10, 12 }) do
      local item = thread(id, "alpha.txt", 60)
      item.pullRequestThreadContext = {
        iterationContext = { firstComparingIteration = 0 },
        trackingCriteria = { origFilePath = "/alpha.txt", origRightFileStart = { line = 60 } },
      }
      tracked[#tracked + 1] = item
    end
    return tracked
  end
  az.list_iterations = function()
    return { { id = 1, commonRefCommit = { commitId = base }, sourceRefCommit = { commitId = head } } }
  end
  az.item_content = function(_, path, commit)
    return git("show", commit .. ":" .. path:gsub("^/", "")) .. "\n"
  end
  az.post_thread = function()
    error("Comment navigation must never write to ADO")
  end
  az.set_vote = az.post_thread
  vim.cmd.cd(vim.fn.fnameescape(fixture))
  vim.cmd("DiffviewOpen " .. state.range())
  local lib = require("diffview.lib")
  assert(vim.wait(15000, function()
    local view = lib.get_current_view()
    return view and view.cur_entry and view.cur_entry.opened
  end, 25))
  local view = lib.get_current_view()
  vim.wait(150)

  vim.cmd("AdoPrComments")
  local picker = Snacks.picker.get()[1]
  assert(vim.wait(10000, function()
    return picker and picker.shown
  end, 25))
  check(
    #picker.opts.items == 12,
    "The real picker lists every human comment and reply, including resolved and PR-level discussions"
  )
  local function item(id, comment)
    for _, row in ipairs(picker.opts.items) do
      if row.thread.id == id and row.comment.id == (comment or 1) then
        return row
      end
    end
    error("Missing comment " .. id)
  end
  picker.opts.preview({ item = item(1), preview = picker.preview })
  check(
    table
      .concat(vim.api.nvim_buf_get_lines(picker.preview.win.buf, 0, -1, false), "\n")
      :find("First line\nSecond line", 1, true),
    "The real picker preview preserves the complete multiline comment"
  )
  local function select(id, comment)
    if picker.closed then
      picker = assert(comments.open())
      assert(vim.wait(10000, function()
        return picker.shown
      end, 25))
    end
    local row = item(id, comment)
    picker.opts.confirm(picker, row)
    vim.wait(300)
  end
  local function at(path, line, side)
    assert(
      vim.wait(15000, function()
        local window = view.cur_layout[side or "b"]
        return view.cur_entry.path == path
          and window
          and vim.api.nvim_win_is_valid(window.id)
          and vim.api.nvim_get_current_win() == window.id
          and vim.api.nvim_win_get_cursor(window.id)[1] == line
      end, 25),
      "Expected " .. path .. ":" .. line .. " on side " .. (side or "b")
    )
  end
  select(1, 2)
  at("beta.txt", 90)
  check(true, "Selecting a reply jumps across files to the exact right-side line")
  select(3)
  at("alpha.txt", 30, "a")
  check(
    view.cur_layout.name == "diff2_horizontal",
    "An old-side comment opens the exact old line, not an inline approximation"
  )
  local function key(keys)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
    vim.wait(150)
  end
  key("]T")
  at("alpha.txt", 70)
  key("[T")
  at("alpha.txt", 30, "a")
  check(true, "The actual next/previous PR-comment shortcuts select the correct side and line")
  select(4)
  at("deleted.txt", 50, "a")
  check(true, "Deleted-file comments open their original side")
  select(5)
  at("new-name.txt", 35, "a")
  check(true, "Renamed-file comments match the old path")
  select(6)
  assert(
    vim.wait(15000, function()
      return vim.b.ado_comment_snapshot and vim.api.nvim_win_get_cursor(0)[1] == 75
    end, 25),
    "Unchanged-file snapshot did not open"
  )
  local snapshot_buffer = vim.api.nvim_get_current_buf()
  check(
    vim.api.nvim_win_get_cursor(0)[1] == 75
      and vim.bo[snapshot_buffer].readonly
      and not vim.bo[snapshot_buffer].modifiable
      and vim.api.nvim_get_current_line() == unchanged .. " line 75",
    "A file absent from the diff opens at its exact line in a read-only commit snapshot"
  )
  check(
    vim.api.nvim_eval_statusline(vim.wo.winbar, { winid = 0 }).str:find(unchanged, 1, true),
    "Snapshot titles treat filenames as literal text, not statusline expressions"
  )
  vim.cmd("AdoPrNextComment")
  vim.wait(300)
  check(
    vim.api.nvim_get_current_tabpage() == view.tabpage,
    "Cross-comment navigation returns from a snapshot to its review"
  )
  select(10)
  assert(
    vim.wait(15000, function()
      return vim.b.ado_comment_snapshot and vim.api.nvim_win_get_cursor(0)[1] == 60
    end, 25),
    "Historical snapshot did not open"
  )
  check(
    vim.api.nvim_win_get_cursor(0)[1] == 60 and vim.api.nvim_get_current_line() == "alpha.txt line 60",
    "Outdated missing-file comments resolve to ADO's original commit and line"
  )
  select(12)
  assert(
    vim.wait(15000, function()
      return vim.b.ado_comment_snapshot and vim.api.nvim_win_get_cursor(0)[1] == 60
    end, 25),
    "Outdated anchor did not open its original snapshot"
  )
  check(
    vim.api.nvim_win_get_cursor(0)[1] == 60,
    "Out-of-range anchors use the original position instead of silently clamping"
  )
  select(7)
  check(vim.api.nvim_get_current_tabpage() == view.tabpage, "PR-level comments do not invent a file anchor")
  select(11)
  assert(
    vim.wait(15000, function()
      return vim.b.ado_comment_snapshot and vim.api.nvim_win_get_cursor(0)[1] == 1
    end, 25),
    "File-level snapshot did not open"
  )
  check(vim.api.nvim_win_get_cursor(0)[1] == 1, "File-level comments open their file without inventing a line anchor")

  vim.api.nvim_set_current_tabpage(view.tabpage)
  picker = assert(comments.open())
  assert(vim.wait(10000, function()
    return picker.shown
  end, 25))
  local stale = item(2)
  local previous_entry = view.cur_entry
  context.id = 43
  picker.opts.confirm(picker, stale)
  vim.wait(200)
  check(view.cur_entry == previous_entry, "A stale picker cannot navigate a different PR")
  context.id = 42
  fail_reads = true
  local notifications, original_notify = {}, vim.notify
  vim.notify = function(message)
    notifications[#notifications + 1] = message
  end
  check(
    comments.open() == nil and table.concat(notifications, "\n"):find("fixture read failure", 1, true),
    "Failed reads report the error rather than showing an empty comments list"
  )
  vim.notify = original_notify
  fail_reads = false
  check(reads > 1, "Opening the list refreshes comments from ADO")
  context.window = { iteration = 1, base_iteration = 1 }
  picker = assert(comments.open())
  check(#picker.opts.items == 2, "Iteration reviews use ADO's tracked positions for that window")
  picker:close()
  context.window = nil
  vim.api.nvim_set_current_tabpage(view.tabpage)
  vim.cmd("DiffviewClose")
  check(
    git("rev-parse", "HEAD") == head and git("status", "--porcelain") == original_status,
    "Comment navigation preserves existing worktree edits, the index, and the PR"
  )
  check(
    vim.deep_equal(global_navigation(), original_navigation),
    "Existing global navigation mappings remain unchanged"
  )
  check(vim.v.errmsg == "", "No asynchronous diff-refresh errors: " .. vim.v.errmsg)
  output[#output + 1] = "PASS"
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.defer_fn(function()
      local ok, err = xpcall(run, debug.traceback)
      if not ok then
        vim.list_extend(output, vim.split(err, "\n", { plain = true }))
      end
      vim.fn.mkdir(root, "p")
      vim.fn.writefile(output, vim.fs.joinpath(root, "results.log"))
      vim.cmd(ok and "qa!" or "cquit")
    end, 500)
  end,
})
