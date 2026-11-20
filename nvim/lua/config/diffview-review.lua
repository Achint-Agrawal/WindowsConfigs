local M = {}
local api, uv = vim.api, vim.uv
local sessions = {}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Hunk review" })
end

local function diff_options()
  -- Match the pinned inline renderer when computing hunks in a side-by-side view.
  local options = { result_type = "indices", indent_heuristic = false, linematch = 60 }
  local flags = {
    ["indent-heuristic"] = "indent_heuristic",
    iwhite = "ignore_whitespace_change",
    iwhiteall = "ignore_whitespace",
    iwhiteeol = "ignore_whitespace_change_at_eol",
    iblank = "ignore_blank_lines",
  }
  for _, option in ipairs(vim.opt.diffopt:get()) do
    local key, value = option:match("^([%w_-]+):(.+)$")
    if key == "algorithm" then
      options.algorithm = value
    elseif key == "linematch" then
      options.linematch = tonumber(value)
    elseif flags[option] then
      options[flags[option]] = true
    end
  end
  return options
end

local function scope(view)
  local commit = require("diffview.vcs.rev").RevType.COMMIT
  if not (view.files and view.left and view.right and view.left.type == commit and view.right.type == commit) then
    return
  end
  local root = uv.fs_realpath(view.adapter.ctx.toplevel) or view.adapter.ctx.toplevel
  if vim.fn.has("win32") == 1 then
    root = root:lower()
  end
  return vim.fn.sha256(vim.json.encode({ root, view.left.commit, view.right.commit, vim.o.diffopt }))
end

local function file_key(entry)
  return vim.fn.sha256(vim.json.encode({ entry.kind, entry.path, entry.oldpath or "" }))
end

local function hunk_key(hunk)
  return table.concat(hunk, ",")
end

local function read_store(path)
  local file, err, code = uv.fs_open(path, "r", 438)
  if not file then
    if code == "ENOENT" then
      return { version = 1, files = {} }
    end
    notify("Cannot read review progress: " .. err, vim.log.levels.ERROR)
    return
  end
  local stat, stat_error = uv.fs_fstat(file)
  local text, read_error
  if stat then
    text, read_error = uv.fs_read(file, stat.size, 0)
  end
  uv.fs_close(file)
  if not text then
    notify("Cannot read review progress: " .. (read_error or stat_error), vim.log.levels.ERROR)
    return
  end
  local ok, data = pcall(vim.json.decode, text)
  local valid = ok and type(data) == "table" and data.version == 1 and type(data.files) == "table"
  if valid then
    for key, record in pairs(data.files) do
      if
        type(key) ~= "string"
        or type(record) ~= "table"
        or type(record.complete) ~= "boolean"
        or type(record.reviewed) ~= "table"
      then
        valid = false
        break
      end
      for hunk, reviewed in pairs(record.reviewed) do
        if type(hunk) ~= "string" or reviewed ~= true then
          valid = false
          break
        end
      end
    end
  end
  if not valid then
    notify("Invalid review progress; refusing to overwrite " .. path, vim.log.levels.ERROR)
    return
  end
  return data
end

local function save(state, changes)
  local data = read_store(state.path)
  if not data then
    return false
  end
  for key, record in pairs(changes) do
    data.files[key] = record
  end
  local ok, err = pcall(vim.fn.mkdir, vim.fs.dirname(state.path), "p")
  if not ok then
    notify("Cannot create review-state directory: " .. err, vim.log.levels.ERROR)
    return false
  end
  local temporary = state.path .. "." .. uv.os_getpid() .. ".tmp"
  local file, open_error = uv.fs_open(temporary, "w", 384)
  if not file then
    notify("Cannot save review progress: " .. open_error, vim.log.levels.ERROR)
    return false
  end
  local text = vim.json.encode(data)
  local written, write_error = uv.fs_write(file, text, 0)
  local closed, close_error = uv.fs_close(file)
  if written ~= #text or not closed then
    uv.fs_unlink(temporary)
    notify("Cannot save review progress: " .. (write_error or close_error or "incomplete write"), vim.log.levels.ERROR)
    return false
  end
  local renamed, rename_error = uv.fs_rename(temporary, state.path)
  if not renamed then
    uv.fs_unlink(temporary)
    notify("Cannot save review progress: " .. rename_error, vim.log.levels.ERROR)
    return false
  end
  state.data = data
  return true
end

local function clear_marks(state)
  for buffer in pairs(state.buffers) do
    if api.nvim_buf_is_valid(buffer) then
      api.nvim_buf_clear_namespace(buffer, state.namespace, 0, -1)
    end
  end
  for window in pairs(state.windows) do
    if api.nvim_win_remove_ns and api.nvim_win_is_valid(window) then
      api.nvim_win_remove_ns(window, state.namespace)
    end
  end
  if not api.nvim_win_remove_ns then
    api.nvim__ns_set(state.namespace, { wins = {} })
  end
  state.buffers, state.windows = {}, {}
end

local function load_scope(state)
  local key = scope(state.view)
  if key ~= state.scope then
    clear_marks(state)
    state.scope, state.current, state.navigation = key, nil, nil
    state.selected = {}
    state.path = key and vim.fs.joinpath(vim.fn.stdpath("state"), "diffview-hunk-review", key .. ".json")
  end
  state.data = state.path and read_store(state.path)
  return state.data ~= nil
end

local function record_for(state, entry)
  return state.data.files[file_key(entry)] or { complete = false, reviewed = {} }
end

local function sync_files(state)
  local selections = require("diffview.api").selections
  local selected = {}
  state.syncing = true
  for _, entry in state.view.files:iter() do
    local complete = record_for(state, entry).complete
    state.selected[file_key(entry)] = complete
    if complete then
      selected[#selected + 1] = entry.path
    end
  end
  selections.set(selected, { view = state.view })
  state.syncing = false
end

local function anchor(hunk, side)
  return math.max(1, hunk[side == "a" and 1 or 3])
end

local function review_hunks(hunks)
  local groups = {}
  for _, hunk in ipairs(hunks) do
    local previous = groups[#groups]
    local overlaps = previous
      and (
        anchor(hunk, "a") <= anchor(previous, "a") + math.max(1, previous[2]) - 1
        or anchor(hunk, "b") <= anchor(previous, "b") + math.max(1, previous[4]) - 1
      )
    if overlaps then
      -- Linematch can split a deletion and modification onto the same cursor row.
      for _, start in ipairs({ 1, 3 }) do
        local first = math.min(math.max(1, previous[start]), math.max(1, hunk[start]))
        local last = math.max(
          math.max(1, previous[start]) + math.max(1, previous[start + 1]),
          math.max(1, hunk[start]) + math.max(1, hunk[start + 1])
        )
        previous[start], previous[start + 1] = first, last - first
      end
    else
      groups[#groups + 1] = vim.deepcopy(hunk)
    end
  end
  return groups
end

local function get_hunks(layout, entry)
  if layout.name == "diff1_inline" then
    local file = layout:get_file_for(entry.status == "D" and "a" or "b")
    if file.binary then
      return {}
    end
    return review_hunks(require("diffview.scene.inline_diff").get_hunks(layout.b.file.bufnr) or {})
  end
  if layout.name ~= "diff2_horizontal" and layout.name ~= "diff2_vertical" then
    return {}
  end
  local function absent(symbol)
    return symbol == "a" and entry.status == "A" or symbol == "b" and entry.status == "D"
  end
  local function content(symbol)
    local file = layout:get_file_for(symbol)
    if absent(symbol) or file.nulled then
      return ""
    end
    return table.concat(api.nvim_buf_get_lines(file.bufnr, 0, -1, false), "\n") .. "\n"
  end
  if not absent("a") and layout.a.file.binary or not absent("b") and layout.b.file.binary then
    return {}
  end
  return review_hunks(vim.text.diff(content("a"), content("b"), diff_options()))
end

local function render(state)
  clear_marks(state)
  local current = state.current
  if not current then
    return
  end
  local record = record_for(state, current.entry)
  for _, side in ipairs(state.view.cur_layout.symbols) do
    local window = state.view.cur_layout[side]
    local buffer = window.file.bufnr
    if buffer and api.nvim_buf_is_valid(buffer) and api.nvim_win_is_valid(window.id) then
      if api.nvim_win_add_ns then
        api.nvim_win_add_ns(window.id, state.namespace)
      end
      state.windows[window.id], state.buffers[buffer] = true, true
      local last = api.nvim_buf_line_count(buffer)
      for index, hunk in ipairs(current.hunks) do
        local reviewed = record.complete or record.reviewed[hunk_key(hunk)]
        api.nvim_buf_set_extmark(buffer, state.namespace, math.min(last, anchor(hunk, side)) - 1, 0, {
          virt_text = {
            {
              (" [%s] hunk %d/%d"):format(reviewed and "x" or " ", index, #current.hunks),
              reviewed and "DiagnosticOk" or "DiagnosticInfo",
            },
          },
          virt_text_pos = "eol",
          priority = 110,
        })
      end
      if not api.nvim_win_add_ns then
        api.nvim__ns_set(state.namespace, { wins = vim.tbl_keys(state.windows) })
      end
    end
  end
end

local function jump(state, index, side)
  local layout = state.view.cur_layout
  local window = layout[side or "b"] or layout:get_main_win()
  local row = math.min(api.nvim_buf_line_count(window.file.bufnr), anchor(state.current.hunks[index], side))
  api.nvim_set_current_win(window.id)
  api.nvim_win_set_cursor(window.id, { row, 0 })
  api.nvim_win_call(window.id, function()
    vim.cmd("normal! zvzz")
  end)
end

local function find_hunk(state, direction, side, line)
  local record = record_for(state, state.current.entry)
  if record.complete then
    return
  end
  local hunks = state.current.hunks
  for step = 1, #hunks do
    local index = direction == 1 and step or #hunks - step + 1
    local row = anchor(hunks[index], side)
    if not record.reviewed[hunk_key(hunks[index])] and (not line or direction * (row - line) > 0) then
      return index
    end
  end
end

local function navigate(state)
  local navigation = state.navigation
  while navigation and navigation.index <= #navigation.entries do
    local entry = navigation.entries[navigation.index]
    if state.current and state.current.entry == entry then
      local index = find_hunk(state, navigation.direction, "b")
      if index then
        state.navigation = nil
        jump(state, index)
        return
      end
    elseif not record_for(state, entry).complete or entry == navigation.origin then
      navigation.target = entry
      state.view:set_file(entry, true)
      return
    end
    navigation.index = navigation.index + 1
  end
  state.navigation = nil
  notify("No unreviewed text hunks remain in this diff.")
end

function M.refresh(view)
  local state = sessions[view]
  if not state or not load_scope(state) then
    return
  end
  sync_files(state)
  local entry = view.cur_entry
  if
    not entry
    or not view.cur_layout
    or entry.revs.a.commit ~= view.left.commit
    or entry.revs.b.commit ~= view.right.commit
  then
    state.current = nil
    clear_marks(state)
    return
  end
  local loading = view:set_file_in_flight()
  if loading and not loading:is_done() then
    return
  end
  for _, side in ipairs(view.cur_layout.symbols) do
    local file = view.cur_layout[side].file
    if not file.bufnr or not api.nvim_buf_is_loaded(file.bufnr) then
      return
    end
  end
  state.current = { entry = entry, hunks = get_hunks(view.cur_layout, entry) }
  render(state)
  if state.navigation then
    navigate(state)
  end
end

function M.selection_changed(view)
  local state = sessions[view]
  if not state or state.syncing then
    return
  end
  if scope(view) ~= state.scope then
    M.refresh(view)
    return
  end
  if not state.data then
    return
  end
  local selections = require("diffview.api").selections
  local changes = {}
  local changed = false
  for _, entry in view.files:iter() do
    local key = file_key(entry)
    local selected = selections.is_selected(entry.path, { view = view, kind = entry.kind })
    if selected ~= (state.selected[key] or false) then
      changes[key] = { complete = selected, reviewed = {} }
      changed = true
    end
  end
  if changed and save(state, changes) then
    M.refresh(view)
  end
end

function M.attach(view)
  if sessions[view] or not view.files then
    return
  end
  local state = {
    view = view,
    namespace = api.nvim_create_namespace("DiffviewHunkReview:" .. view.tabpage),
    buffers = {},
    windows = {},
  }
  sessions[view] = state
  view.emitter:on("file_open_pre", function(_, entry)
    clear_marks(state)
    if state.navigation and state.navigation.target ~= entry then
      state.navigation = nil
    end
  end)
  view.emitter:on("file_open_post", function(_, entry)
    vim.schedule(function()
      if sessions[view] == state and view.cur_entry == entry and view:is_cur_tabpage() then
        M.refresh(view)
      end
    end)
  end)
  view.emitter:on("files_updated", function()
    M.refresh(view)
  end)
end

function M.detach(view)
  if sessions[view] then
    clear_marks(sessions[view])
    sessions[view] = nil
  end
end

local function context()
  local view = require("diffview.lib").get_current_view()
  local state = view and sessions[view]
  if not state or not load_scope(state) then
    notify("Hunk review requires a saved Git commit-to-commit diff, such as an ADO PR.", vim.log.levels.WARN)
    return
  end
  state.navigation = nil
  local loading = view:set_file_in_flight()
  if loading and not loading:is_done() then
    notify("Wait for the diff file to finish loading.", vim.log.levels.WARN)
    return
  end
  if not state.current or state.current.entry ~= view.cur_entry then
    M.refresh(view)
  end
  if not state.current or state.current.entry ~= view.cur_entry then
    notify("Wait for the diff file to finish loading.", vim.log.levels.WARN)
    return
  end
  return state
end

function M.toggle_hunk()
  local state = context()
  if not state then
    return
  end
  local layout = state.view.cur_layout
  local side = layout.a and layout.a.id == api.nvim_get_current_win() and "a" or "b"
  local window = layout[side]
  if not window or window.id ~= api.nvim_get_current_win() then
    notify("Focus a changed line in the diff pane to review its hunk.", vim.log.levels.WARN)
    return
  end
  local line = api.nvim_win_get_cursor(window.id)[1]
  local index
  for i, hunk in ipairs(state.current.hunks) do
    local start, count = anchor(hunk, side), hunk[side == "a" and 2 or 4]
    if line >= start and line <= start + math.max(1, count) - 1 then
      index = i
      break
    end
  end
  if not index then
    notify(
      "No text hunk under the cursor. Use ]r to find one; use w in the file list for non-text changes.",
      vim.log.levels.WARN
    )
    return
  end
  local entry, hunks = state.current.entry, state.current.hunks
  local record = vim.deepcopy(record_for(state, entry))
  if record.complete then
    for _, hunk in ipairs(hunks) do
      record.reviewed[hunk_key(hunk)] = true
    end
  end
  local key = hunk_key(hunks[index])
  record.reviewed[key] = not record.reviewed[key] and true or nil
  local count = 0
  for _, hunk in ipairs(hunks) do
    if record.reviewed[hunk_key(hunk)] then
      count = count + 1
    end
  end
  record.complete = count == #hunks
  if save(state, { [file_key(entry)] = record }) then
    M.refresh(state.view)
    notify(("%s: %d/%d hunks reviewed"):format(entry.path, count, #hunks))
  end
end

function M.next_unreviewed(direction)
  local state = context()
  if not state then
    return
  end
  direction = direction or 1
  state.navigation = nil
  local layout = state.view.cur_layout
  local side = layout.a and layout.a.id == api.nvim_get_current_win() and "a" or "b"
  local window = layout[side] or layout:get_main_win()
  local line = window.id == api.nvim_get_current_win() and api.nvim_win_get_cursor(window.id)[1] or nil
  local index = find_hunk(state, direction, side, line)
  if index then
    jump(state, index, side)
    return
  end
  local files, current = {}, nil
  for _, entry in state.view.files:iter() do
    files[#files + 1] = entry
    if entry == state.current.entry then
      current = #files
    end
  end
  if not current then
    notify("The diff file list changed; reopen the review.", vim.log.levels.WARN)
    return
  end
  local entries = {}
  for step = 1, #files do
    entries[#entries + 1] = files[(current - 1 + direction * step) % #files + 1]
  end
  state.navigation = { entries = entries, index = 1, direction = direction, origin = state.current.entry }
  navigate(state)
end

return M
