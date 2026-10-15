local line = assert(tonumber(arg[1]), "Missing LazyGit line number")
local paths = { unpack(arg, 2) }
assert(#paths > 0, "Missing LazyGit file path")
-- LazyGit caret-escapes metacharacters even inside quoted Windows paths.
for i, path in ipairs(paths) do
  paths[i] = path:gsub("%^([%^&|<>%%])", "%1")
end
local server = assert(vim.env.NVIM, "LazyGit must be launched inside Neovim")
local channel = vim.fn.sockconnect("pipe", server, { rpc = true })
assert(channel > 0, "Unable to connect to the Neovim instance")

vim.rpcrequest(
  channel,
  "nvim_exec_lua",
  [[
  local paths, line = ...
  local terminal = vim.bo.channel
  assert(terminal > 0, "LazyGit terminal is not the current buffer")
  vim.cmd.stopinsert()
  vim.cmd.wincmd("p")
  vim.api.nvim_command("drop " .. table.concat(vim.tbl_map(vim.fn.fnameescape, paths), " "))
  if line > 0 then
    vim.fn.cursor(line, 1)
  end
  -- Leave the staging view before quitting LazyGit.
  assert(vim.fn.chansend(terminal, "qq") > 0, "Unable to close LazyGit")
]],
  { paths, line }
)
vim.fn.chanclose(channel)
