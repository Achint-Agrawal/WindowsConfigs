-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.filetype.add({
  extension = {
    props = "xml",
    targets = "xml",
    proj = "xml",
    sqlproj = "xml",
    nuproj = "xml",
    resx = "xml",
    ruleset = "xml",
  },
})
