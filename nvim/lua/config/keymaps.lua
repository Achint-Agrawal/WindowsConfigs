-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local function relative_path(base, path)
  local windows = vim.fn.has("win32") == 1
  base, path = vim.fs.normalize(base), vim.fs.normalize(path)
  local target = windows and path:lower() or path
  if windows then
    base = base:lower()
    local base_volume = base:match("^//[^/]+/[^/]+") or base:match("^%a:")
    local target_volume = target:match("^//[^/]+/[^/]+") or target:match("^%a:")
    if base_volume ~= target_volume then
      return
    end
  end
  local prefix = ""
  while base do
    local relative = vim.fs.relpath(base, target)
    if relative then
      local result = prefix .. (relative == "." and "." or path:sub(-#relative))
      if windows then
        result = result:gsub("/", "\\")
      end
      return result
    end
    local parent = vim.fs.dirname(base)
    if parent == base then
      break
    end
    base, prefix = parent, prefix .. "../"
  end
end

local function copy_file_path(format)
  if vim.bo.buftype ~= "" or vim.api.nvim_buf_get_name(0) == "" then
    vim.notify("The current buffer has no file path.", vim.log.levels.WARN)
    return
  end

  local path = vim.fn.expand("%:p")
  local suffix = ""
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local anchor, cursor = vim.fn.line("v"), vim.fn.line(".")
    local first, last = math.min(anchor, cursor), math.max(anchor, cursor)
    suffix = ":" .. first
    if first ~= last then
      suffix = suffix .. "-" .. last
    end
  end

  local text = path
  if format == "r" then
    local root = vim.fs.root(path, ".git")
    if not root then
      vim.notify("The current file is not in a Git repository.", vim.log.levels.WARN)
      return
    end
    text = relative_path(root, path)
  elseif format == "c" then
    text = relative_path(vim.fn.getcwd(), path)
  elseif format == "n" then
    text = vim.fn.fnamemodify(path, ":t")
  end
  if not text then
    vim.notify("A relative path cannot cross Windows drives or network shares.", vim.log.levels.WARN)
    return
  end
  text = text .. suffix
  vim.fn.setreg("+", text, "c")
  vim.notify(text, vim.log.levels.INFO, { title = "Copied file path" })
end

for key, label in pairs({
  a = "Absolute Path",
  r = "Git-relative Path",
  c = "Working-directory-relative Path",
  n = "File Name",
}) do
  vim.keymap.set({ "n", "x" }, "<leader>fy" .. key, function()
    copy_file_path(key)
  end, { desc = "Copy " .. label })
end
