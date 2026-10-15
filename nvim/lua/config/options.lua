-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.snacks_animate = false
vim.opt.guicursor:append("a:blinkon0")

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
