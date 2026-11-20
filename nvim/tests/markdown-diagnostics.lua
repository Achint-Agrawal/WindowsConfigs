local root = assert(vim.env.NVIM_MARKDOWN_TEST_DIR, "Set NVIM_MARKDOWN_TEST_DIR to a fresh temporary directory")
local output = {}
local function check(value, message)
  assert(value, message)
  output[#output + 1] = "OK " .. message
end

local function extmarks(buffer, namespace, handler)
  local id = vim.diagnostic.get_namespace(namespace).user_data[handler]
  return id and #vim.api.nvim_buf_get_extmarks(buffer, id, 0, -1, {}) or 0
end

local function run()
  -- Headless startup does not emit UIEnter to load VeryLazy configuration.
  require("lazyvim.config").load("autocmds")
  require("lazyvim.config").load("keymaps")
  local fixture = vim.fs.joinpath(root, "fixture")
  assert(vim.fn.isdirectory(fixture) == 0, "Use a fresh test directory")
  vim.fn.mkdir(fixture, "p")
  vim.fn.writefile({
    '{"default":false,"MD013":true,"MD060":{"style":"aligned"}}',
  }, vim.fs.joinpath(fixture, ".markdownlint.json"))
  local path = vim.fs.joinpath(fixture, "report.md")
  local lines = {
    "# Technical report",
    "",
    string.rep("TechnicalIdentifier ", 8),
    "",
    "| Item | Details |",
    "| --- | --- |",
    "| A | Longer details |",
  }
  vim.fn.writefile(lines, path)
  vim.api.nvim_set_current_dir(fixture)
  vim.cmd.edit(vim.fn.fnameescape(path))
  local buffer = vim.api.nvim_get_current_buf()
  local text = vim.lsp._buf_get_full_text(buffer)

  require("lazy").load({ plugins = { "nvim-lint" } })
  local lint = require("lint")
  local namespace = lint.get_namespace("markdownlint-cli2")
  lint.try_lint("markdownlint-cli2")
  assert(
    vim.wait(15000, function()
      return #vim.diagnostic.get(buffer, { namespace = namespace }) > 0 and #lint.get_running(buffer) == 0
    end, 25),
    "Markdownlint did not publish diagnostics"
  )
  local diagnostics = vim.diagnostic.get(buffer, { namespace = namespace })
  for _, code in ipairs({ "MD013", "MD060" }) do
    check(
      vim.iter(diagnostics):any(function(item)
        return item.message:find(code, 1, true) ~= nil
      end),
      code .. " remains collected without changing the project's lint rules"
    )
  end
  check(extmarks(buffer, namespace, "virt_text_ns") == 0, "Markdownlint does not crowd source with inline text")
  check(extmarks(buffer, namespace, "underline_ns") == 0, "Markdownlint does not underline formatting issues")
  check(extmarks(buffer, namespace, "sign_ns") > 0, "Markdownlint gutter signs remain available")
  check(not vim.wo.spell and vim.wo.wrap, "Markdown defaults to no spelling underlines while retaining wrapping")
  vim.api.nvim_exec_autocmds("FileType", { buffer = buffer, modeline = false })
  check(not vim.wo.spell, "Reapplying Markdown filetype does not restore spelling underlines")

  local spelling = vim.fn.maparg("<leader>us", "n", false, true)
  assert(type(spelling.callback) == "function", "The existing spelling toggle is missing")
  spelling.callback()
  check(vim.wo.spell, "Space u s can still enable spelling on demand")
  spelling.callback()
  check(not vim.wo.spell, "Space u s can turn spelling off again")

  local diagnostic = diagnostics[1]
  vim.api.nvim_win_set_cursor(0, { diagnostic.lnum + 1, diagnostic.col })
  local float, win = vim.diagnostic.open_float(buffer, { scope = "line", focus = false })
  check(float and vim.iter(vim.api.nvim_buf_get_lines(float, 0, -1, false)):any(function(line)
    return line:find("MD013", 1, true) ~= nil
  end), "Line diagnostics still show the original markdownlint warning on demand")
  vim.api.nvim_win_close(win, true)

  local other_namespace = vim.api.nvim_create_namespace("markdown-language-server-test")
  vim.diagnostic.set(other_namespace, buffer, {
    { lnum = 0, col = 2, end_col = 8, message = "Broken reference", severity = vim.diagnostic.severity.WARN },
  })
  check(
    extmarks(buffer, other_namespace, "virt_text_ns") > 0 and extmarks(buffer, other_namespace, "underline_ns") > 0,
    "Other Markdown diagnostic sources still show warnings inline and underlined"
  )
  check(
    vim.lsp._buf_get_full_text(buffer) == text and not vim.bo[buffer].modified,
    "Display preferences never modify Markdown content"
  )
  check(vim.deep_equal(vim.fn.readfile(path), lines), "Markdown content on disk remains unchanged")

  vim.cmd.enew()
  vim.cmd.setfiletype("cs")
  local cs = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(cs, 0, -1, false, { "invalid C#;" })
  vim.diagnostic.set(other_namespace, cs, {
    {
      lnum = 0,
      col = 0,
      end_col = 7,
      message = "Genuine compiler error",
      severity = vim.diagnostic.severity.ERROR,
      code = "CS1002",
    },
  })
  check(
    extmarks(cs, other_namespace, "virt_text_ns") > 0 and extmarks(cs, other_namespace, "underline_ns") > 0,
    "C# compiler errors keep their existing inline text and underlines"
  )
  vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
  vim.wo.spell = true
  vim.cmd.setfiletype("markdown.mdx")
  check(not vim.wo.spell, "Markdown MDX also defaults to no spelling underlines")
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
