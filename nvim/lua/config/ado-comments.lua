local M = {}
local api, uv = vim.api, vim.uv
local session

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "PR comments" })
end

local function root(path)
  path = vim.fs.normalize(uv.fs_realpath(path) or path)
  return vim.fn.has("win32") == 1 and path:lower() or path
end

local function signature(ctx, view)
  return vim.json.encode({
    ctx.id,
    ctx.repositoryId,
    root(ctx.repo_root),
    ctx.base,
    ctx.head or "",
    ctx.window and ctx.window.iteration or 0,
    ctx.window and ctx.window.base_iteration or 0,
    view.left.commit,
    view.right.commit,
  })
end

local function review()
  local ctx = require("ado-pr.state").get()
  local view = require("diffview.lib").get_current_view()
  if not view and session and session.context_tab == api.nvim_get_current_tabpage() then
    view = session.view
  end
  if
    not (ctx and ctx.repo_root and view and view.files and api.nvim_tabpage_is_valid(view.tabpage))
    or view.rev_arg ~= require("ado-pr.state").range()
    or root(ctx.repo_root) ~= root(view.adapter.ctx.toplevel)
  then
    notify("Open an ADO PR review first with :AdoPr or :AdoPrReview.", vim.log.levels.WARN)
    return
  end
  return ctx, view
end

local function valid(owner)
  local ctx = require("ado-pr.state").get()
  return session == owner
    and ctx
    and api.nvim_tabpage_is_valid(owner.view.tabpage)
    and signature(ctx, owner.view) == owner.signature
    and owner.view.rev_arg == require("ado-pr.state").range()
end

local function location(item)
  if not item.path then
    return "PR-level"
  end
  return item.path .. (item.range and (":%d (%s)"):format(item.range.line_start, item.range.side) or " (file-level)")
end

local function lines(item)
  local comment = item.comment
  local author = type(comment.author) == "table" and comment.author.displayName or "Unknown author"
  local result = {
    ("Thread #%s / comment #%s [%s]"):format(item.thread.id, comment.id, item.thread.status or "unknown"),
    location(item),
    author .. "  " .. (comment.publishedDate or ""),
    "",
  }
  vim.list_extend(result, vim.split(comment.content or "", "\n", { plain = true }))
  return result
end

local function fetch(ctx, view)
  local az = require("ado-pr.az")
  local threads, err
  if ctx.window then
    threads, err = az.list_threads_tracked(ctx, ctx.window.iteration, ctx.window.base_iteration)
  else
    threads, err = az.list_threads(ctx)
  end
  if not threads then
    notify("Cannot load PR comments: " .. (err or "unknown error"), vim.log.levels.ERROR)
    return
  end
  local items, helpers = {}, require("ado-pr.threads")
  for _, thread in ipairs(threads) do
    if not thread.isDeleted then
      local tc = type(thread.threadContext) == "table" and thread.threadContext or nil
      local path = tc and type(tc.filePath) == "string" and helpers.norm_repo_path(tc.filePath) or nil
      local range = tc
          and (type(tc.rightFileStart) == "table" or type(tc.leftFileStart) == "table")
          and helpers.resolve(thread, ctx.window)
        or nil
      for _, comment in ipairs(thread.comments or {}) do
        if not comment.isDeleted and comment.commentType ~= "system" and comment.commentType ~= 3 then
          local item = { thread = thread, comment = comment, path = path, range = range }
          item.text = table
            .concat({
              location(item),
              "[" .. (thread.status or "unknown") .. "]",
              (type(comment.author) == "table" and comment.author.displayName) or "Unknown author",
              ("#%s/%s"):format(thread.id, comment.id),
              comment.content or "",
            }, "  ")
            :gsub("%c", " ")
          items[#items + 1] = item
        end
      end
    end
  end
  table.sort(items, function(a, b)
    if a.path ~= b.path then
      return (a.path or "\255") < (b.path or "\255")
    end
    local al, bl = a.range and a.range.line_start or 0, b.range and b.range.line_start or 0
    if al ~= bl then
      return al < bl
    end
    if a.thread.id ~= b.thread.id then
      return a.thread.id < b.thread.id
    end
    return a.comment.id < b.comment.id
  end)
  local previous = session and session.view == view and session.signature == signature(ctx, view) and session or nil
  local owner = {
    ctx = ctx,
    view = view,
    signature = signature(ctx, view),
    items = items,
    context_tab = previous and previous.context_tab,
    context_win = previous and previous.context_win,
  }
  for index, item in ipairs(items) do
    item.index = index
    local selected = previous and previous.items[previous.index or 0]
    if selected and selected.thread.id == item.thread.id and selected.comment.id == item.comment.id then
      owner.index = index
    end
  end
  session = owner
  return owner
end

local function maps(buffer)
  vim.keymap.set("n", "]T", function()
    M.next(1)
  end, { buffer = buffer, desc = "Next PR comment" })
  vim.keymap.set("n", "[T", function()
    M.next(-1)
  end, { buffer = buffer, desc = "Previous PR comment" })
end

local function show_comment(item)
  local buffer, window = vim.lsp.util.open_floating_preview(lines(item), "markdown", {
    border = "rounded",
    focus = false,
    max_width = 90,
    max_height = 16,
  })
  vim.bo[buffer].modeline = false
  maps(buffer)
  vim.keymap.set("n", "q", function()
    if api.nvim_win_is_valid(window) then
      api.nvim_win_close(window, true)
    end
  end, { buffer = buffer, desc = "Close comment" })
end

local function file_lines(text)
  local content = vim.split(text:gsub("\r\n", "\n"), "\n", { plain = true })
  if content[#content] == "" then
    table.remove(content)
  end
  return content
end

local function snapshot(owner, item, spec)
  local content = file_lines(spec.content)
  if spec.line < 1 or spec.line > math.max(1, #content) then
    notify("The comment's original line is unavailable; refusing to jump to a different line.", vim.log.levels.ERROR)
    return
  end
  local name = ("ado-comment://%s/%s/%s/%s"):format(owner.ctx.id, owner.view.tabpage, spec.commit, spec.path)
  local buffer = vim.fn.bufnr(name)
  if buffer == -1 then
    buffer = api.nvim_create_buf(false, true)
    api.nvim_buf_set_name(buffer, name)
    api.nvim_buf_set_lines(buffer, 0, -1, false, content)
    vim.bo[buffer].buftype, vim.bo[buffer].bufhidden = "nofile", "wipe"
    vim.bo[buffer].swapfile, vim.bo[buffer].modeline = false, false
    vim.bo[buffer].filetype = vim.filetype.match({ filename = spec.path }) or ""
    vim.bo[buffer].modifiable, vim.bo[buffer].readonly = false, true
    vim.b[buffer].ado_comment_snapshot = true
    maps(buffer)
    vim.keymap.set("n", "q", function()
      vim.cmd("tabclose")
      if api.nvim_tabpage_is_valid(owner.view.tabpage) then
        api.nvim_set_current_tabpage(owner.view.tabpage)
      end
    end, { buffer = buffer, desc = "Return to PR review" })
  elseif vim.bo[buffer].modified then
    notify("The comment snapshot has unsaved edits; refusing to replace it.", vim.log.levels.ERROR)
    return
  end
  if
    owner.context_win
    and api.nvim_win_is_valid(owner.context_win)
    and vim.b[api.nvim_win_get_buf(owner.context_win)].ado_comment_snapshot
    and not vim.bo[api.nvim_win_get_buf(owner.context_win)].modified
  then
    api.nvim_set_current_tabpage(owner.context_tab)
    api.nvim_set_current_win(owner.context_win)
  else
    vim.cmd("tabnew")
    owner.context_tab, owner.context_win = api.nvim_get_current_tabpage(), api.nvim_get_current_win()
  end
  api.nvim_win_set_buf(owner.context_win, buffer)
  vim.wo[owner.context_win].winbar = ("PR %s | %s @ %s")
    :format(owner.ctx.id, spec.path, spec.commit:sub(1, 8))
    :gsub("%%", "%%%%")
  api.nvim_win_set_cursor(owner.context_win, { spec.line, 0 })
  vim.cmd("normal! zvzz")
  show_comment(item)
end

local function original(owner, item)
  local az, archaeology = require("ado-pr.az"), require("ado-pr.archaeology")
  local iterations, err = az.list_iterations(owner.ctx)
  if not iterations then
    return nil, err
  end
  local window = archaeology.tracked_window(owner.ctx.window, iterations)
  local threads
  threads, err = az.list_threads_tracked(owner.ctx, window.iteration, window.base_iteration)
  if not threads then
    return nil, err
  end
  for _, thread in ipairs(threads) do
    if thread.id == item.thread.id then
      local anchor = require("ado-pr.threads").original(thread)
      local iteration = archaeology.origin_iteration_id(thread)
      if not anchor or iteration == nil then
        break
      end
      local commit
      commit, err = archaeology.commit_for_iteration(iterations, iteration)
      if not commit then
        return nil, err
      end
      local content
      content, err = az.item_content(owner.ctx, "/" .. anchor.path, commit)
      if not content then
        return nil, err
      end
      return { commit = commit, path = anchor.path, line = anchor.line_start, content = content }
    end
  end
  return nil, "ADO did not provide an original tracked position"
end

local function historical(owner, item)
  local spec, err = original(owner, item)
  if spec then
    notify("Showing the comment's original revision.")
    snapshot(owner, item, spec)
  else
    notify("Cannot locate " .. location(item) .. ": " .. (err or "unknown error"), vim.log.levels.ERROR)
  end
end

local function jump(owner, item)
  if not valid(owner) then
    notify("The PR or revision changed; reopen the comments list.", vim.log.levels.WARN)
    return
  end
  owner.index, owner.pending = item.index, {}
  api.nvim_set_current_tabpage(owner.view.tabpage)
  if not item.path then
    show_comment(item)
    return
  end
  if not item.range then
    notify("File-level comment: ADO supplied no line anchor.")
  end
  local view, entry = owner.view
  local normalize = require("ado-pr.threads").norm_repo_path
  for _, candidate in view.files:iter() do
    if
      normalize(candidate.path) == item.path
      or item.range and item.range.side == "left" and normalize(candidate.oldpath) == item.path
    then
      entry = candidate
      break
    end
  end
  if not entry then
    local commit = item.range and item.range.side == "left" and view.left.commit or view.right.commit
    local result = vim
      .system({ "git", "show", commit .. ":" .. item.path }, { cwd = owner.ctx.repo_root, text = true })
      :wait()
    if result.code == 0 and (not item.range or item.range.line_start <= #file_lines(result.stdout)) then
      snapshot(
        owner,
        item,
        { commit = commit, path = item.path, line = item.range and item.range.line_start or 1, content = result.stdout }
      )
    else
      historical(owner, item)
    end
    return
  end
  local ticket, started = owner.pending, uv.hrtime()
  view:set_file(entry, true)
  local function finish()
    if not valid(owner) or owner.pending ~= ticket or not view:is_cur_tabpage() then
      return
    end
    if uv.hrtime() - started > 15e9 then
      notify("Timed out loading the comment's diff file.", vim.log.levels.ERROR)
      return
    end
    local loading = view:set_file_in_flight()
    if loading and not loading:is_done() then
      vim.defer_fn(finish, 20)
      return
    end
    if view.cur_entry ~= entry then
      return
    end
    local side = item.range and item.range.side == "left" and "a" or "b"
    if not item.range and entry.status == "D" then
      side = "a"
    end
    if side == "a" and not view.cur_layout.a then
      -- Deleted/changed old lines are virtual text in inline mode, not addressable rows.
      require("diffview.actions").set_layout("diff2_horizontal")()
      vim.defer_fn(finish, 20)
      return
    end
    local window, line = view.cur_layout[side], item.range and item.range.line_start or 1
    if window.file.nulled or line > api.nvim_buf_line_count(window.file.bufnr) then
      historical(owner, item)
      return
    end
    api.nvim_set_current_win(window.id)
    api.nvim_win_set_cursor(window.id, { line, 0 })
    vim.cmd("normal! zvzz")
    show_comment(item)
  end
  vim.schedule(finish)
end

function M.open()
  local ctx, view = review()
  if not ctx then
    return
  end
  local owner = fetch(ctx, view)
  if not owner then
    return
  end
  if #owner.items == 0 then
    notify("This PR has no human comments.")
    return
  end
  return Snacks.picker({
    title = ("PR %s comments"):format(ctx.id),
    items = owner.items,
    format = "text",
    preview = function(preview)
      preview.preview:reset()
      preview.preview:set_lines(lines(preview.item))
      preview.preview:wo({ wrap = true })
      preview.preview:highlight({ ft = "markdown" })
    end,
    confirm = function(picker, item)
      picker:close()
      if item then
        vim.schedule(function()
          jump(owner, item)
        end)
      end
    end,
  })
end

function M.next(direction)
  local ctx, view = review()
  if not ctx then
    return
  end
  local owner = session and session.view == view and valid(session) and session or fetch(ctx, view)
  if not owner then
    return
  end
  if #owner.items == 0 then
    notify("This PR has no human comments.")
    return
  end
  direction = direction or 1
  local index = owner.index and (owner.index - 1 + direction) % #owner.items + 1
    or (direction < 0 and #owner.items or 1)
  jump(owner, owner.items[index])
end

return M
