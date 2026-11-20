local root = assert(vim.env.NVIM_EOL_TEST_DIR, "Set NVIM_EOL_TEST_DIR to a fresh temporary directory")
local output = {}
local function check(value, message)
  assert(value, message)
  output[#output + 1] = "OK " .. message
end

local function run()
  local fixture = vim.fs.joinpath(root, "fixture")
  assert(vim.fn.isdirectory(fixture) == 0, "Use a fresh test directory")
  vim.fn.mkdir(fixture, "p")
  local function write(path, text)
    local file = assert(vim.uv.fs_open(path, "w", 438))
    assert(vim.uv.fs_write(file, text, 0) == #text)
    assert(vim.uv.fs_close(file))
  end
  local function read(path)
    local file = assert(vim.uv.fs_open(path, "r", 438))
    local stat = assert(vim.uv.fs_fstat(file))
    local text = assert(vim.uv.fs_read(file, stat.size, 0))
    assert(vim.uv.fs_close(file))
    return text
  end
  local function git(...)
    local command = {
      "git",
      "-c",
      "core.autocrlf=false",
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
    local result = vim.system(command, { cwd = fixture }):wait()
    assert(result.code == 0, result.stderr)
    return result.stdout
  end
  write(
    vim.fs.joinpath(fixture, ".editorconfig"),
    "root = true\n[*]\nend_of_line = crlf\nindent_style = space\nindent_size = 3\n"
      .. "[lf-policy.txt]\nend_of_line = lf\n"
  )
  write(vim.fs.joinpath(fixture, ".gitattributes"), "* -text\n")
  local original = "first\r\nsecond\r\nthird\nfourth\r\n"
  local changed = "first\r\nsecond\r\ninserted\r\nthird\nfourth\r\n"
  local mixed = vim.fs.joinpath(fixture, "mixed.txt")
  write(mixed, original)
  git("init", "--quiet")
  git("add", ".")
  git("commit", "--quiet", "-m", "Mixed line endings")
  write(mixed, changed)
  local original_notify, notices = vim.notify, {}
  vim.notify = function(message, level)
    notices[#notices + 1] = { message = message, level = level }
  end
  vim.api.nvim_set_current_dir(fixture)
  vim.cmd.edit(vim.fn.fnameescape(mixed))
  local buffer = vim.api.nvim_get_current_buf()
  check(
    vim.lsp._buf_get_full_text(buffer) == read(mixed),
    "LSP document text matches the actual mixed-ending file without doubled CRs"
  )
  check(vim.bo.fileformat == "unix", "Mixed endings retain the detected LF buffer representation")
  check(vim.bo.shiftwidth == 3 and vim.bo.expandtab, "Other EditorConfig properties still apply")
  check(not vim.bo.modified, "Opening the file does not create unsaved edits")
  check(
    vim.iter(notices):any(function(item)
      return item.level == vim.log.levels.WARN and item.message:find("Mixed", 1, true)
    end),
    "Skipped line-ending conversion produces an explicit warning"
  )
  local property, notice_count = require("editorconfig").properties.end_of_line, #notices
  require("config.line-endings").setup()
  check(require("editorconfig").properties.end_of_line == property, "Repeated setup does not wrap EditorConfig again")
  require("editorconfig").config(buffer)
  check(#notices == notice_count, "Reapplying EditorConfig warns only once per file")
  check(vim.lsp._buf_get_full_text(buffer) == changed, "Reapplying EditorConfig preserves the exact document text")
  check(not pcall(property, buffer, "invalid"), "Invalid line-ending values still raise the built-in error")

  require("lazy").load({ plugins = { "gitsigns.nvim" } })
  require("gitsigns").attach(buffer)
  assert(
    vim.wait(10000, function()
      local hunks = require("gitsigns").get_hunks(buffer)
      return hunks and #hunks > 0
    end, 25),
    "GitSigns did not attach"
  )
  local hunks = require("gitsigns").get_hunks(buffer)
  check(
    #hunks == 1 and hunks[1].added.count == 1 and hunks[1].removed.count == 0 and hunks[1].added.start == 3,
    "GitSigns reports only the actual single inserted line"
  )
  check(git("diff", "--numstat", "--", "mixed.txt"):match("^1%s+0%s+"), "Git CLI and GitSigns agree on the change")
  local status = git("status", "--porcelain")
  local command = vim.lsp._buf_get_full_text(buffer)
  check(
    table.concat(require("gitsigns.util").buf_lines(buffer), "\n") == changed,
    "GitSigns serializes the exact same bytes as Git and LSP"
  )
  vim.cmd.write()
  check(read(mixed) == changed and command == changed, "An unchanged save preserves every original CRLF/LF byte")
  check(git("status", "--porcelain") == status, "Saving does not introduce new Git changes")

  for _, case in ipairs({
    { name = "mixed-no-eol", text = "one\r\ntwo\nthree", expected = "one\r\ntwo\nthree", format = "unix" },
    { name = "lf-first", text = "one\ntwo\r\nthree\r\n", expected = "one\ntwo\r\nthree\r\n", format = "unix" },
    { name = "lf-policy", text = changed, expected = changed, format = "unix" },
    { name = "crlf", text = "one\r\ntwo\r\n", expected = "one\r\ntwo\r\n", format = "dos" },
    { name = "lf", text = "one\ntwo\n", expected = "one\r\ntwo\r\n", format = "dos" },
  }) do
    local path = vim.fs.joinpath(fixture, case.name .. ".txt")
    write(path, case.text)
    vim.cmd.edit(vim.fn.fnameescape(path))
    check(
      vim.bo.fileformat == case.format and vim.lsp._buf_get_full_text(0) == case.expected,
      case.name .. " retains safe, intended EditorConfig behavior"
    )
    check(read(path) == case.text, case.name .. " is never rewritten merely by opening")
  end
  local path = vim.fs.joinpath(fixture, "new.txt")
  vim.cmd.edit(vim.fn.fnameescape(path))
  check(
    vim.bo.fileformat == "dos" and vim.bo.shiftwidth == 3,
    "New files still honor the project newline and indent settings"
  )
  check(
    vim.diagnostic.config().virtual_text.severity.min == vim.diagnostic.severity.WARN,
    "The errors-and-warnings display filter is unchanged"
  )
  local namespace = vim.api.nvim_create_namespace("eol-compiler-test")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a genuine compiler error" })
  vim.diagnostic.set(namespace, 0, {
    {
      lnum = 0,
      col = 0,
      end_col = 5,
      message = "Real compiler error",
      severity = vim.diagnostic.severity.ERROR,
      code = "CS1002",
    },
  })
  check(#vim.diagnostic.get(0) == 1, "Genuine compiler errors remain collected")
  local diagnostic_ns = vim.diagnostic.get_namespace(namespace)
  check(
    #vim.api.nvim_buf_get_extmarks(0, diagnostic_ns.user_data.virt_text_ns, 0, -1, {}) > 0,
    "Genuine compiler errors remain visible inline"
  )
  vim.notify = original_notify
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
